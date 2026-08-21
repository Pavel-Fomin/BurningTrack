//
//  BatchFilenameRenamePlanBuilder.swift
//  TrackList
//
//  Чистые правила подготовки массового переименования файлов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Строит и обновляет план batch rename без UI, mutable session или файловых операций.
struct BatchFilenameRenamePlanBuilder {
    /// Состояние строки после завершившейся попытки применения.
    private struct PreservedAppliedState {
        /// Статус, полученный при физическом переименовании.
        let status: BatchFilenameRenameStatus
        /// Целевое имя, для которого был получен этот статус.
        let targetFileName: String
        /// Исходная mutation failure остаётся единственным источником partial-success семантики.
        let failure: MutationFailure?
    }

    /// Проверяет обязательные metadata до выбора стратегии.
    func makeMetadataValidationItems(
        for tracks: [BatchFilenameRenameTrack]
    ) -> [BatchFilenameRenameItem] {
        tracks.map { track in
            let artist = normalized(track.artist)
            let title = normalized(track.title)
            let status = missingMetadataStatus(artist: artist, title: title) ?? .ready

            return BatchFilenameRenameItem(
                trackId: track.trackId,
                folderPath: track.folderPath,
                currentFileName: track.currentFileName,
                targetFileName: track.currentFileName,
                artist: artist,
                title: title,
                strategy: nil,
                status: status,
                mutationFailure: nil
            )
        }
    }

    /// Пересобирает preview по стратегии, сохраняя применённые статусы прежнего плана.
    func makePlan(
        strategy: FilenameRenameStrategy,
        tracks: [BatchFilenameRenameTrack],
        preserving existingItems: [BatchFilenameRenameItem]
    ) -> [BatchFilenameRenameItem] {
        let preservedStates = preservedAppliedStates(from: existingItems)
        let rebuiltItems = makeUniqueTargetNames(
            in: tracks.map { makePlanItem(strategy: strategy, track: $0) }
        )

        return rebuiltItems.map { item in
            guard let preservedState = preservedStates[item.trackId] else {
                return item
            }

            if preservedState.status == .renamed,
               preservedState.targetFileName != item.targetFileName {
                return item.withStatus(.ready)
            }

            if let failure = preservedState.failure {
                return item.withMutationFailure(failure, status: preservedState.status)
            }

            return item.withStatus(preservedState.status)
        }
    }

    /// Преобразует только готовые строки плана в команды существующего batch writer.
    func makeCommands(
        from items: [BatchFilenameRenameItem]
    ) -> [BatchFilenameRenameCommand] {
        items.compactMap { item in
            guard item.status == .ready else { return nil }

            return BatchFilenameRenameCommand(
                trackId: item.trackId,
                currentFileName: item.currentFileName,
                targetFileName: item.targetFileName
            )
        }
    }

    /// Применяет typed-результат writer к существующим строкам, не затрагивая неучаствующие.
    func applying(
        _ result: BatchFilenameRenameResult,
        to items: [BatchFilenameRenameItem]
    ) -> [BatchFilenameRenameItem] {
        let succeededIds = Set(result.succeeded.map(\.trackId))
        let failedById = Dictionary(
            uniqueKeysWithValues: result.failed.map { ($0.trackId, $0) }
        )

        return items.map { item in
            if succeededIds.contains(item.trackId) {
                return item.withStatus(.renamed)
            }

            if let failure = failedById[item.trackId] {
                return item.withMutationFailure(
                    failure.failure,
                    status: status(for: failure.failure)
                )
            }

            return item
        }
    }

    /// Собирает один элемент плана и сохраняет исходное расширение файла.
    private func makePlanItem(
        strategy: FilenameRenameStrategy,
        track: BatchFilenameRenameTrack
    ) -> BatchFilenameRenameItem {
        let artist = normalized(track.artist)
        let title = normalized(track.title)
        let missingStatus = missingMetadataStatus(artist: artist, title: title)
        let targetBaseName = targetBaseName(strategy: strategy, artist: artist, title: title)
        let sanitizedBaseName = sanitizedFileName(targetBaseName)
        let targetFileName = fileNameWithOriginalExtension(
            baseName: sanitizedBaseName,
            originalFileName: track.currentFileName
        )
        let status: BatchFilenameRenameStatus

        if let missingStatus {
            status = missingStatus
        } else if sanitizedBaseName.isEmpty || !isValidTargetFileName(targetFileName) {
            status = .invalidTargetName
        } else {
            status = .ready
        }

        return BatchFilenameRenameItem(
            trackId: track.trackId,
            folderPath: track.folderPath,
            currentFileName: track.currentFileName,
            targetFileName: status == .ready ? targetFileName : track.currentFileName,
            artist: artist,
            title: title,
            strategy: strategy,
            status: status,
            mutationFailure: nil
        )
    }

    /// Делает целевые имена уникальными только внутри выбранных строк одной папки.
    private func makeUniqueTargetNames(
        in items: [BatchFilenameRenameItem]
    ) -> [BatchFilenameRenameItem] {
        var usedNamesByFolder: [String: Set<String>] = [:]

        return items.map { item in
            guard item.status == .ready else { return item }

            let targetFileName = uniqueFileName(
                baseFileName: item.targetFileName,
                folderPath: item.folderPath,
                usedNamesByFolder: &usedNamesByFolder
            )

            return BatchFilenameRenameItem(
                trackId: item.trackId,
                folderPath: item.folderPath,
                currentFileName: item.currentFileName,
                targetFileName: targetFileName,
                artist: item.artist,
                title: item.title,
                strategy: item.strategy,
                status: item.status,
                mutationFailure: nil
            )
        }
    }

    /// Сохраняет состояния строк, для которых операция применения уже завершалась.
    private func preservedAppliedStates(
        from items: [BatchFilenameRenameItem]
    ) -> [UUID: PreservedAppliedState] {
        Dictionary(
            uniqueKeysWithValues: items.compactMap { item in
                switch item.status {
                case .renamed,
                     .applyFailed,
                     .trackIsPlaying,
                     .fileAccessDenied:
                    return (
                        item.trackId,
                        PreservedAppliedState(
                            status: item.status,
                            targetFileName: item.targetFileName,
                            failure: item.mutationFailure
                        )
                    )
                case .ready,
                     .missingArtist,
                     .missingTitle,
                     .missingArtistAndTitle,
                     .invalidTargetName:
                    return nil
                }
            }
        )
    }

    /// Возвращает уникальное имя файла внутри папки, добавляя числовой суффикс перед расширением.
    private func uniqueFileName(
        baseFileName: String,
        folderPath: String,
        usedNamesByFolder: inout [String: Set<String>]
    ) -> String {
        let folderKey = folderPath.lowercased()
        var usedNames = usedNamesByFolder[folderKey, default: []]
        let url = URL(fileURLWithPath: baseFileName)
        let fileExtension = url.pathExtension
        let nameWithoutExtension = fileExtension.isEmpty
            ? baseFileName
            : String(baseFileName.dropLast(fileExtension.count + 1))
        var candidate = baseFileName
        var index = 1

        while usedNames.contains(candidate.lowercased()) {
            candidate = fileExtension.isEmpty
                ? "\(nameWithoutExtension) \(index)"
                : "\(nameWithoutExtension) \(index).\(fileExtension)"
            index += 1
        }

        usedNames.insert(candidate.lowercased())
        usedNamesByFolder[folderKey] = usedNames
        return candidate
    }

    /// Возвращает статус отсутствующих тегов, если они нужны для выбранного формата имени.
    private func missingMetadataStatus(
        artist: String,
        title: String
    ) -> BatchFilenameRenameStatus? {
        switch (artist.isEmpty, title.isEmpty) {
        case (true, true): return .missingArtistAndTitle
        case (true, false): return .missingArtist
        case (false, true): return .missingTitle
        case (false, false): return nil
        }
    }

    /// Формирует базовое имя файла без расширения по выбранной стратегии.
    private func targetBaseName(
        strategy: FilenameRenameStrategy,
        artist: String,
        title: String
    ) -> String {
        switch strategy {
        case .artistTitle: return "\(artist) - \(title)"
        case .titleArtist: return "\(title) - \(artist)"
        }
    }

    /// Добавляет исходное расширение файла к новому имени.
    private func fileNameWithOriginalExtension(
        baseName: String,
        originalFileName: String
    ) -> String {
        let originalExtension = URL(fileURLWithPath: originalFileName).pathExtension
        return originalExtension.isEmpty ? baseName : "\(baseName).\(originalExtension)"
    }

    /// Нормализует строку metadata перед построением имени файла.
    private func normalized(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Заменяет символы, недопустимые в имени файла, на пробелы.
    private func sanitizedFileName(_ value: String) -> String {
        let forbiddenCharacters = CharacterSet(charactersIn: "/\\:?%*|\"<>")
            .union(.controlCharacters)
        var sanitized = value
            .components(separatedBy: forbiddenCharacters)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        while sanitized.contains("  ") {
            sanitized = sanitized.replacingOccurrences(of: "  ", with: " ")
        }

        return sanitized
    }

    /// Проверяет, что имя можно использовать как будущую цель переименования.
    private func isValidTargetFileName(_ fileName: String) -> Bool {
        let normalizedFileName = normalized(fileName)
        return !normalizedFileName.isEmpty
            && normalizedFileName != "."
            && normalizedFileName != ".."
    }

    /// Сохраняет уже существующий row-status, а точный текст partial failure получает Presenter из MutationFailure.
    private func status(for failure: MutationFailure) -> BatchFilenameRenameStatus {
        switch failure.appError {
        case .fileAccessDenied,
             .bookmarkResolveFailed,
             .bookmarkMissing,
             .bookmarkStale:
            return .fileAccessDenied
        default:
            return .applyFailed
        }
    }
}

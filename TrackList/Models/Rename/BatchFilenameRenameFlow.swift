//
//  BatchFilenameRenameFlow.swift
//  TrackList
//
//  Состояние подготовки массового переименования файлов.
//
//  Роль:
//  - принимает зафиксированный выбор треков;
//  - отделяет старт flow от физического переименования файлов;
//  - строит данные плана без изменения файловой системы.
//
//  Created by Pavel Fomin on 21.05.2026.
//

import Foundation
import Combine

enum FilenameRenameStrategy: Equatable {
    /// Имя файла строится в формате "исполнитель - название".
    case artistTitle

    /// Имя файла строится в формате "название - исполнитель".
    case titleArtist
}

enum BatchFilenameRenameStatus: Equatable {
    /// Элемент готов для будущего применения.
    case ready

    /// Файл успешно переименован.
    case renamed

    /// В метаданных нет исполнителя.
    case missingArtist

    /// В метаданных нет названия.
    case missingTitle

    /// В метаданных нет исполнителя и названия.
    case missingArtistAndTitle

    /// Целевое имя не удалось собрать в допустимое имя файла.
    case invalidTargetName

    /// Файл не удалось переименовать.
    case applyFailed

    /// Файл сейчас используется плеером.
    case trackIsPlaying

    /// Нет доступа к файлу или папке.
    case fileAccessDenied
}

/// Фаза массового переименования файлов.
enum BatchFilenameRenamePhase: Equatable {
    /// Metadata выбранных файлов загружается.
    /// Sheet уже может быть открыт, но стратегия и применение должны быть недоступны.
    case loadingMetadata

    /// Пользователь подготавливает список.
    case preparing

    /// Переименование уже применялось хотя бы один раз.
    case applied
}

struct BatchFilenameRenameTrack: Equatable {
    /// Идентификатор трека из TrackRegistry.
    let trackId: UUID

    /// Путь родительской папки нужен для генерации уникальных имён внутри одной папки.
    let folderPath: String

    /// Текущее имя файла с расширением.
    let currentFileName: String

    /// Исполнитель из runtime snapshot или исходных тегов фонотеки.
    let artist: String?

    /// Название из runtime snapshot или исходных тегов фонотеки.
    let title: String?
}

struct BatchFilenameRenameItem: Identifiable, Equatable {
    /// Идентификатор элемента совпадает с trackId для стабильного связывания с треком.
    var id: UUID { trackId }

    /// Идентификатор трека из TrackRegistry.
    let trackId: UUID

    /// Путь родительской папки исходного файла.
    let folderPath: String

    /// Текущее имя файла с исходным расширением.
    let currentFileName: String

    /// Новое имя файла с сохранённым исходным расширением.
    let targetFileName: String

    /// Исполнитель, использованный при построении плана.
    let artist: String?

    /// Название, использованное при построении плана.
    let title: String?

    /// Стратегия, по которой построено целевое имя.
    /// До выбора стратегии значение отсутствует, потому что выполняется только проверка метаданных.
    let strategy: FilenameRenameStrategy?

    /// Статус элемента плана.
    var status: BatchFilenameRenameStatus
}

extension BatchFilenameRenameTrack {
    /// Имя файла, которое показывается до выбора стратегии.
    var displayedFileName: String {
        currentFileName
    }
}

extension BatchFilenameRenameItem {
    /// Имя или ошибка, которые показываются в списке текущего плана.
    var displayedFileName: String {
        switch status {
        case .ready,
             .renamed,
             .applyFailed,
             .trackIsPlaying,
             .fileAccessDenied:
            return targetFileName
        case .missingArtist,
             .missingTitle,
             .missingArtistAndTitle,
             .invalidTargetName:
            return currentFileName
        }
    }

    /// Текст статуса элемента плана.
    var statusDescription: String? {
        switch status {
        case .ready:
            return nil
        case .renamed:
            return "Переименовано"
        case .missingArtist:
            return "Не заполнен артист"
        case .missingTitle:
            return "Не заполнено название"
        case .missingArtistAndTitle:
            return "Не заполнены артист и название"
        case .invalidTargetName:
            return "Некорректное имя файла"
        case .applyFailed:
            return "Не удалось переименовать файл"
        case .trackIsPlaying:
            return "Файл сейчас используется плеером"
        case .fileAccessDenied:
            return "Нет доступа к файлу"
        }
    }

    /// Является ли текущий статус ошибкой.
    var isErrorStatus: Bool {
        switch status {
        case .ready,
             .renamed:
            return false
        case .missingArtist,
             .missingTitle,
             .missingArtistAndTitle,
             .invalidTargetName,
             .applyFailed,
             .trackIsPlaying,
             .fileAccessDenied:
            return true
        }
    }

    /// Является ли текущий статус успешным результатом применения.
    var isSuccessStatus: Bool {
        status == .renamed
    }

    /// Возвращает копию элемента с новым статусом.
    func withStatus(_ newStatus: BatchFilenameRenameStatus) -> BatchFilenameRenameItem {
        BatchFilenameRenameItem(
            trackId: trackId,
            folderPath: folderPath,
            currentFileName: currentFileName,
            targetFileName: targetFileName,
            artist: artist,
            title: title,
            strategy: strategy,
            status: newStatus
        )
    }
}

final class BatchFilenameRenameFlow: ObservableObject {
    /// Состояние строки после попытки применения.
    private struct PreservedAppliedState {
        /// Статус, полученный после применения операции.
        let status: BatchFilenameRenameStatus

        /// Целевое имя файла, с которым был получен статус.
        let targetFileName: String
    }

    /// Pending-действие, с которым будет строиться следующий шаг переименования.
    @Published private(set) var pendingAction: PendingBulkTrackAction?

    /// Исходные треки, оставленные пользователем в операции.
    @Published private(set) var tracks: [BatchFilenameRenameTrack] = []

    /// Стратегия, по которой построен текущий план.
    @Published private(set) var strategy: FilenameRenameStrategy?

    /// Текущая фаза массового переименования.
    @Published private(set) var phase: BatchFilenameRenamePhase = .preparing

    /// Данные будущего preview массового переименования.
    @Published private(set) var items: [BatchFilenameRenameItem] = []

    /// Выполняется ли сейчас чтение тегов для подготовки переименования.
    @Published private(set) var isPreparingRename = false

    /// Количество треков, для которых уже прочитаны данные.
    @Published private(set) var preparedRenameCount = 0

    /// Общее количество треков, отправленных на чтение тегов.
    @Published private(set) var totalPrepareCount = 0

    /// Выполняется ли сейчас применение массового переименования.
    @Published private(set) var isApplyingRename = false

    /// Количество файлов, уже обработанных во время применения.
    @Published private(set) var processedRenameCount = 0

    /// Общее количество файлов, отправленных на применение.
    @Published private(set) var totalRenameCount = 0

    /// Совместимое имя для уже построенного плана переименования.
    var plan: [BatchFilenameRenameItem] {
        items
    }

    /// Показывает, начат ли flow массового переименования.
    var isActive: Bool {
        pendingAction != nil
    }

    /// Показывает, занята ли операция подготовкой или применением.
    var isBusy: Bool {
        isPreparingRename || isApplyingRename
    }

    /// Можно ли применить текущий план массового переименования.
    var canApplyRename: Bool {
        guard !isBusy else { return false }
        guard phase != .loadingMetadata else { return false }
        guard strategy != nil else { return false }

        return items.contains { item in
            item.status == .ready
        }
    }

    /// Активирует flow до завершения чтения metadata.
    ///
    /// Используется, чтобы sheet открылся сразу и показал список выбранных файлов
    /// по текущим именам, пока artist/title ещё загружаются.
    func startLoadingMetadata(
        with pendingAction: PendingBulkTrackAction,
        tracks: [BatchFilenameRenameTrack]
    ) {
        self.pendingAction = pendingAction
        self.tracks = tracks
        strategy = nil
        phase = .loadingMetadata
        items = []
        resetApplyingRenameProgress()
    }

    /// Запоминает выбор для будущего построения плана переименования.
    func prepare(
        with pendingAction: PendingBulkTrackAction,
        tracks: [BatchFilenameRenameTrack]
    ) {
        self.pendingAction = pendingAction
        self.tracks = tracks
        strategy = nil
        phase = .preparing
        items = []
        resetApplyingRenameProgress()
    }

    /// Строит план переименования без записи на диск.
    func buildPlan(
        strategy: FilenameRenameStrategy,
        tracks: [BatchFilenameRenameTrack]
    ) {
        let preservedStates = preservedAppliedStates()

        self.strategy = strategy
        self.tracks = tracks
        let rebuiltItems = makeUniqueTargetNames(
            in: tracks.map { makePlanItem(strategy: strategy, track: $0) }
        )

        items = rebuiltItems.map { item in
            guard let preservedState = preservedStates[item.trackId] else {
                return item
            }

            if preservedState.status == .renamed,
               preservedState.targetFileName != item.targetFileName {
                return item.withStatus(.ready)
            }

            return item.withStatus(preservedState.status)
        }
    }

    /// Выполняет первичную проверку обязательных метаданных до выбора стратегии.
    func validateRequiredMetadata() {
        items = tracks.map { track in
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
                status: status
            )
        }
    }

    /// Убирает трек только из текущей операции массового переименования.
    func removeTrack(id: UUID) {
        tracks.removeAll { $0.trackId == id }
        items.removeAll { $0.trackId == id }

        if let pendingAction {
            self.pendingAction = PendingBulkTrackAction(
                action: pendingAction.action,
                trackIDs: pendingAction.trackIDs.filter { $0 != id }
            )
        }

        guard phase == .preparing else { return }

        if let strategy {
            buildPlan(strategy: strategy, tracks: tracks)
        } else {
            validateRequiredMetadata()
        }
    }

    /// Применяет результат массового переименования к текущему плану.
    func applyResult(_ result: BatchFilenameRenameResult) {
        let succeededIds = Set(result.succeeded.map(\.trackId))
        let failedById = Dictionary(
            uniqueKeysWithValues: result.failed.map { ($0.trackId, $0) }
        )

        items = items.map { item in
            if succeededIds.contains(item.trackId) {
                return item.withStatus(.renamed)
            }

            if let failure = failedById[item.trackId] {
                return item.withStatus(status(for: failure.error))
            }

            return item
        }

        phase = .applied
    }

    /// Запускает отображение прогресса массового переименования.
    func startApplyingRename(totalCount: Int) {
        isApplyingRename = true
        processedRenameCount = 0
        totalRenameCount = totalCount
    }

    /// Обновляет количество уже обработанных файлов.
    func updateApplyingRenameProgress(processedCount: Int) {
        processedRenameCount = processedCount
    }

    /// Завершает отображение прогресса массового переименования.
    func finishApplyingRename() {
        isApplyingRename = false
    }

    /// Запускает отображение прогресса чтения тегов.
    func startPreparingRename(totalCount: Int) {
        isPreparingRename = true
        preparedRenameCount = 0
        totalPrepareCount = totalCount
    }

    /// Обновляет количество треков, для которых уже прочитаны данные.
    func updatePreparingRenameProgress(preparedCount: Int) {
        preparedRenameCount = preparedCount
    }

    /// Завершает отображение прогресса чтения тегов.
    func finishPreparingRename() {
        isPreparingRename = false
    }

    /// Сбрасывает состояние массового переименования файлов.
    func reset() {
        pendingAction = nil
        tracks = []
        strategy = nil
        phase = .preparing
        items = []
        resetPreparingRenameProgress()
        resetApplyingRenameProgress()
    }

    /// Сбрасывает значения прогресса чтения тегов.
    private func resetPreparingRenameProgress() {
        isPreparingRename = false
        preparedRenameCount = 0
        totalPrepareCount = 0
    }

    /// Сбрасывает значения прогресса применения.
    private func resetApplyingRenameProgress() {
        isApplyingRename = false
        processedRenameCount = 0
        totalRenameCount = 0
    }

    /// Собирает один элемент плана и сохраняет исходное расширение файла.
    private func makePlanItem(
        strategy: FilenameRenameStrategy,
        track: BatchFilenameRenameTrack
    ) -> BatchFilenameRenameItem {
        let artist = normalized(track.artist)
        let title = normalized(track.title)
        let missingStatus = missingMetadataStatus(artist: artist, title: title)
        let targetBaseName = targetBaseName(
            strategy: strategy,
            artist: artist,
            title: title
        )
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
            status: status
        )
    }

    /// Делает целевые имена уникальными внутри каждой папки.
    private func makeUniqueTargetNames(
        in items: [BatchFilenameRenameItem]
    ) -> [BatchFilenameRenameItem] {
        var usedNamesByFolder: [String: Set<String>] = [:]

        return items.map { item in
            guard item.status == .ready else {
                return item
            }

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
                status: item.status
            )
        }
    }

    /// Сохраняет состояния строк, для которых операция применения уже завершалась.
    private func preservedAppliedStates() -> [UUID: PreservedAppliedState] {
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
                            targetFileName: item.targetFileName
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
            if fileExtension.isEmpty {
                candidate = "\(nameWithoutExtension) \(index)"
            } else {
                candidate = "\(nameWithoutExtension) \(index).\(fileExtension)"
            }

            index += 1
        }

        usedNames.insert(candidate.lowercased())
        usedNamesByFolder[folderKey] = usedNames
        return candidate
    }

    /// Возвращает статус отсутствующих тегов, если они нужны для стратегии.
    private func missingMetadataStatus(
        artist: String,
        title: String
    ) -> BatchFilenameRenameStatus? {
        switch (artist.isEmpty, title.isEmpty) {
        case (true, true):
            return .missingArtistAndTitle
        case (true, false):
            return .missingArtist
        case (false, true):
            return .missingTitle
        case (false, false):
            return nil
        }
    }

    /// Формирует базовое имя файла без расширения по выбранной стратегии.
    private func targetBaseName(
        strategy: FilenameRenameStrategy,
        artist: String,
        title: String
    ) -> String {
        switch strategy {
        case .artistTitle:
            return "\(artist) - \(title)"
        case .titleArtist:
            return "\(title) - \(artist)"
        }
    }

    /// Добавляет исходное расширение файла к новому имени.
    private func fileNameWithOriginalExtension(
        baseName: String,
        originalFileName: String
    ) -> String {
        let originalExtension = URL(fileURLWithPath: originalFileName).pathExtension

        guard !originalExtension.isEmpty else {
            return baseName
        }

        return "\(baseName).\(originalExtension)"
    }

    /// Нормализует строку метаданных перед построением имени файла.
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

    /// Проверяет, что имя можно показать как будущую цель переименования.
    private func isValidTargetFileName(_ fileName: String) -> Bool {
        let normalizedFileName = normalized(fileName)
        return !normalizedFileName.isEmpty
            && normalizedFileName != "."
            && normalizedFileName != ".."
    }

    /// Преобразует ошибку применения в статус строки плана.
    private func status(for error: Error) -> BatchFilenameRenameStatus {
        if let libraryError = error as? LibraryFileError {
            switch libraryError {
            case .trackIsPlaying:
                return .trackIsPlaying
            case .sourceURLUnavailable,
                 .destinationFolderUnavailable,
                 .bookmarkCreationFailed,
                 .relativePathFailed:
                return .fileAccessDenied
            case .trackNotFound,
                 .destinationAlreadyExists,
                 .moveFailed:
                return .applyFailed
            }
        }

        return .applyFailed
    }
}

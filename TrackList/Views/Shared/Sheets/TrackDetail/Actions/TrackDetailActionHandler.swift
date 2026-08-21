//
//  TrackDetailActionHandler.swift
//  TrackList
//
//  Выполняет загрузку и сохранение временного сценария Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Результат первичной загрузки Track Detail без UI-зависимостей.
enum TrackDetailLoadResult {
    /// Получены готовый snapshot, presentation URL и признак purchased iTunes источника.
    case loaded(
        snapshot: TrackRuntimeSnapshot,
        fileURL: URL?,
        isPurchasedITunes: Bool
    )
    /// Runtime-данные нельзя подготовить для отображения.
    case unavailable
}

/// Неизменяемый draft, достаточный для построения точной команды сохранения.
struct TrackDetailSaveDraft {
    /// Идентификатор физического трека.
    let trackId: UUID
    /// Полное имя файла baseline, включая исходное расширение.
    let baselineFullFileName: String
    /// Основа имени файла baseline.
    let baselineFileName: String
    /// Исходные значения тегов.
    let baselineValues: [EditableTrackField: String]
    /// Исходное состояние artwork.
    let baselineArtwork: ArtworkEditState
    /// Текущая основа имени файла.
    let fileName: String
    /// Текущие значения тегов.
    let editableValues: [EditableTrackField: String]
    /// Текущее состояние artwork.
    let artwork: ArtworkEditState
}

/// Выполняет Track Detail flow без зависимости от SwiftUI View.
@MainActor
final class TrackDetailActionHandler {
    /// Возвращает последний готовый runtime snapshot.
    private let snapshotProvider: any TrackDetailSnapshotProviding
    /// Собирает runtime snapshot, если кэш ещё пуст.
    private let snapshotBuilder: any TrackDetailSnapshotBuilding
    /// Резолвит URL локального трека для presentation пути.
    private let fileURLResolver: any TrackDetailFileURLResolving
    /// Выполняет существующую атомарную save-команду.
    private let commandExecutor: any TrackDetailCommandExecuting
    /// Проверяет, занят ли файл текущим плеером.
    private let fileBusyChecker: any TrackFileBusyChecking
    /// Освобождает файл только после подтверждения пользователя.
    private let playbackFileReleaser: any CurrentPlaybackFileReleasing
    /// Преобразует результаты команды в presentation feedback.
    private let presenter: TrackDetailPresenter
    /// Закрывает sheet через общий lifecycle.
    private let router: any TrackDetailRouting
    /// Неизменяемая идентичность конкретного Track Detail route.
    private let routeID: UUID

    /// Последняя точная команда, ожидающая остановки воспроизведения.
    private var pendingSaveCommand: TrackDetailSaveCommand?

    init(
        snapshotProvider: any TrackDetailSnapshotProviding,
        snapshotBuilder: any TrackDetailSnapshotBuilding,
        fileURLResolver: any TrackDetailFileURLResolving,
        commandExecutor: any TrackDetailCommandExecuting,
        fileBusyChecker: any TrackFileBusyChecking,
        playbackFileReleaser: any CurrentPlaybackFileReleasing,
        presenter: TrackDetailPresenter,
        router: any TrackDetailRouting,
        routeID: UUID = UUID()
    ) {
        self.snapshotProvider = snapshotProvider
        self.snapshotBuilder = snapshotBuilder
        self.fileURLResolver = fileURLResolver
        self.commandExecutor = commandExecutor
        self.fileBusyChecker = fileBusyChecker
        self.playbackFileReleaser = playbackFileReleaser
        self.presenter = presenter
        self.router = router
        self.routeID = routeID
    }

    /// Загружает runtime-данные выбранного local или purchased iTunes трека.
    func load(track: any TrackDisplayable) async -> TrackDetailLoadResult {
        if let purchasedTrack = track.asPurchasedITunesPlayableTrack() {
            let snapshot = await snapshotBuilder.buildSnapshot(
                forPurchasedITunesTrack: purchasedTrack
            )
            return .loaded(
                snapshot: snapshot,
                fileURL: nil,
                isPurchasedITunes: true
            )
        }

        guard let fileURL = await fileURLResolver.fileURL(forTrackId: track.trackId) else {
            return .unavailable
        }

        if let snapshot = snapshotProvider.snapshot(forTrackId: track.trackId) {
            return .loaded(
                snapshot: snapshot,
                fileURL: fileURL,
                isPurchasedITunes: false
            )
        }

        do {
            guard let snapshot = try await snapshotBuilder.buildSnapshot(
                forTrackId: track.trackId
            ) else {
                return .unavailable
            }

            return .loaded(
                snapshot: snapshot,
                fileURL: fileURL,
                isPurchasedITunes: false
            )
        } catch {
            return .unavailable
        }
    }

    /// Запускает сохранение подготовленного ViewModel draft.
    func save(_ draft: TrackDetailSaveDraft) async -> TrackDetailSavePresentation {
        guard let command = makeSaveCommand(from: draft) else {
            return .keepEditing(alert: nil)
        }

        return await execute(command)
    }

    /// Останавливает playback только после подтверждения alert и повторяет сохранённую команду.
    func confirmStopPlayback() async -> TrackDetailSavePresentation {
        guard let pendingSaveCommand else {
            return .keepEditing(alert: nil)
        }

        playbackFileReleaser.releaseCurrentPlaybackFile()
        return await execute(pendingSaveCommand)
    }

    /// Закрывает Track Detail только через общий router.
    func close() {
        router.dismissTrackDetail(routeID)
    }

    /// Выполняет одну уже сформированную команду без повторного чтения UI-state.
    private func execute(
        _ command: TrackDetailSaveCommand
    ) async -> TrackDetailSavePresentation {
        do {
            let result = try await commandExecutor.saveTrackEdits(
                trackId: command.trackId,
                newFileName: command.newFileName,
                fileChanged: command.fileChanged,
                patch: command.patch,
                tagsChanged: command.tagsChanged,
                artworkAction: command.artworkAction,
                artworkChanged: command.artworkChanged,
                using: fileBusyChecker
            )
            pendingSaveCommand = nil

            return presenter.present(
                result,
                confirmedSnapshot: result.snapshot
            )
        } catch let appError as AppError {
            if case .fileAccessDenied = appError {
                pendingSaveCommand = command
            } else {
                pendingSaveCommand = nil
            }
            return presenter.present(appError)
        } catch {
            pendingSaveCommand = nil
            return presenter.presentUnknownSaveFailure()
        }
    }

    /// Строит единую domain-команду из baseline и draft без зависимости от View.
    private func makeSaveCommand(
        from draft: TrackDetailSaveDraft
    ) -> TrackDetailSaveCommand? {
        let newFileName = fullFileName(
            baseName: draft.fileName,
            originalFileName: draft.baselineFullFileName
        )
        let patch = makeTagWritePatch(
            baseline: draft.baselineValues,
            draft: draft.editableValues
        )

        guard let patch else { return nil }

        let artworkAction = draft.artwork.makeWriteAction()
        return TrackDetailSaveCommand(
            trackId: draft.trackId,
            newFileName: newFileName,
            fileChanged: newFileName != draft.baselineFullFileName,
            patch: patch,
            tagsChanged: normalized(draft.editableValues)
                != normalized(draft.baselineValues),
            artworkAction: artworkAction,
            artworkChanged: artworkAction != .none
        )
    }

    /// Формирует patch тегов; nil означает недопустимый year, который не должен быть записан.
    private func makeTagWritePatch(
        baseline: [EditableTrackField: String],
        draft: [EditableTrackField: String]
    ) -> TagWritePatch? {
        func stringChange(
            _ field: EditableTrackField
        ) -> TagFieldChange<String> {
            let initial = normalized(baseline[field] ?? "")
            let current = normalized(draft[field] ?? "")

            if current == initial { return .unchanged }
            if current.isEmpty { return .clear }
            return .set(current)
        }

        let initialYear = normalized(baseline[.year] ?? "")
        let currentYear = normalized(draft[.year] ?? "")
        let yearChange: TagFieldChange<Int>
        if currentYear == initialYear {
            yearChange = .unchanged
        } else if currentYear.isEmpty {
            yearChange = .clear
        } else if let year = Int(currentYear) {
            yearChange = .set(year)
        } else {
            return nil
        }

        var patch = TagWritePatch()
        patch.title = stringChange(.title)
        patch.artist = stringChange(.artist)
        patch.album = stringChange(.album)
        patch.genre = stringChange(.genre)
        patch.comment = stringChange(.comment)
        patch.publisher = stringChange(.publisher)
        patch.year = yearChange
        return patch
    }

    /// Добавляет исходное расширение к нормализованной основе имени файла.
    private func fullFileName(
        baseName: String,
        originalFileName: String
    ) -> String {
        let normalizedBaseName = normalized(baseName)
        let fileExtension = (originalFileName as NSString).pathExtension

        guard !fileExtension.isEmpty else {
            return normalizedBaseName
        }

        return "\(normalizedBaseName).\(fileExtension)"
    }

    /// Убирает пробелы и переносы строк по краям значения.
    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Нормализует все редактируемые значения перед сравнением.
    private func normalized(
        _ values: [EditableTrackField: String]
    ) -> [EditableTrackField: String] {
        values.mapValues(normalized)
    }
}

/// Точная команда сохранения, которая может быть повторена после остановки playback.
private struct TrackDetailSaveCommand {
    /// Идентификатор физического трека.
    let trackId: UUID
    /// Полное целевое имя файла.
    let newFileName: String
    /// Нужно ли физически переименовать файл.
    let fileChanged: Bool
    /// Изменения текстовых и числовых тегов.
    let patch: TagWritePatch
    /// Нужно ли выполнять запись тегов.
    let tagsChanged: Bool
    /// Итоговое действие с artwork.
    let artworkAction: ArtworkWriteAction
    /// Нужно ли выполнять запись artwork.
    let artworkChanged: Bool
}

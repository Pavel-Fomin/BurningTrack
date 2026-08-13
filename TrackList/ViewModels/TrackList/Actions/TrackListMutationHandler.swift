//
//  TrackListMutationHandler.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает изменения содержимого одного треклиста.
/// Отвечает за удаление, перемещение и действия, которые меняют данные строк.
@MainActor
final class TrackListMutationHandler {

    /// Читает актуальный detail snapshot, не владея его состоянием.
    private let reader: any TrackListReading
    /// Сохраняет новый порядок и публикует detail invalidation.
    private let trackListManager: any TrackListManaging
    /// Выполняет доменную команду удаления ровно одного вхождения строки.
    private let commandExecutor: any TrackListCommandExecuting
    /// Показывает результат или семантическую ошибку команды.
    private let toastPresenter: any ToastPresenting

    /// Создаёт обработчик изменений одного треклиста.
    init(
        reader: any TrackListReading,
        trackListManager: any TrackListManaging,
        commandExecutor: any TrackListCommandExecuting,
        toastPresenter: any ToastPresenting
    ) {
        self.reader = reader
        self.trackListManager = trackListManager
        self.commandExecutor = commandExecutor
        self.toastPresenter = toastPresenter
    }

    /// Удаляет трек из текущего треклиста по идентификатору строки.
    func deleteTrack(rowId: UUID) {
        guard reader.track(forRowId: rowId) != nil else {
            return
        }

        let trackListId = reader.trackListId
        let commandExecutor = commandExecutor
        let toastPresenter = toastPresenter

        Task {
            do {
                let result = try await commandExecutor.removeTrackFromTrackList(
                    listItemId: rowId,
                    trackListId: trackListId
                )
                await AppCommandToastPresenter(
                    toastPresenter: toastPresenter
                ).present(result)
            } catch let appError as AppError {
                toastPresenter.handle(appError)
            } catch {
                toastPresenter.handle(.trackListSaveFailed)
            }
        }
    }

    /// Перемещает треки внутри текущего треклиста.
    func moveTrack(
        from source: IndexSet,
        to destination: Int
    ) {
        let tracks = reader.tracks
        guard source.isEmpty == false,
              source.allSatisfy({ tracks.indices.contains($0) }),
              (0...tracks.count).contains(destination) else {
            return
        }

        let sourceIndexes = source.sorted()
        let movedTracks = sourceIndexes.map { tracks[$0] }
        var reorderedTracks = tracks

        for index in sourceIndexes.reversed() {
            reorderedTracks.remove(at: index)
        }

        let adjustedDestination = destination - sourceIndexes.filter { $0 < destination }.count
        reorderedTracks.insert(
            contentsOf: movedTracks,
            at: adjustedDestination
        )

        guard trackListManager.saveTracks(
            reorderedTracks,
            for: reader.trackListId
        ) else {
            toastPresenter.handle(.trackListSaveFailed)
            return
        }
    }

}

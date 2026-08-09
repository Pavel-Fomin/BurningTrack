//
//  RenameTrackListActionHandler.swift
//  TrackList
//
//  Обрабатывает действия sheet-flow переименования треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
final class RenameTrackListActionHandler {

    /// Управляет метаданными треклистов.
    private let trackListsService: any TrackListsManaging
    /// Показывает пользовательские сообщения.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизирует завершение rename-sheet.
    private let router: any RenameTrackListRouting
    /// Неизменяемая идентичность конкретного rename route.
    private let routeID: UUID

    init(
        trackListsService: any TrackListsManaging,
        toastPresenter: any ToastPresenting,
        router: any RenameTrackListRouting,
        routeID: UUID = UUID()
    ) {
        self.trackListsService = trackListsService
        self.toastPresenter = toastPresenter
        self.router = router
        self.routeID = routeID
    }

    /// Закрывает rename-sheet без выполнения доменной команды.
    func cancel() {
        router.dismissRenameTrackList(routeID)
    }

    /// Переименовывает треклист и закрывает sheet только после успешной команды.
    func rename(
        trackListId: UUID,
        newName: String
    ) -> RenameTrackListResult {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else { return .failure }

        do {
            try trackListsService.renameTrackList(
                id: trackListId,
                to: trimmedName
            )
            toastPresenter.handle(.trackListRenamed(newName: trimmedName))
            router.dismissRenameTrackList(routeID)
            return .success
        } catch let appError as AppError {
            PersistentLogger.log("RenameTrackListActionHandler: rename tracklist failed error=\(appError)")
            toastPresenter.handle(appError)
            return .failure
        } catch {
            PersistentLogger.log("RenameTrackListActionHandler: rename tracklist failed error=\(error)")
            toastPresenter.handle(AppError.trackListSaveFailed)
            return .failure
        }
    }
}

/// Результат доменной операции переименования для координации flow.
enum RenameTrackListResult: Equatable {
    case success
    case failure
}

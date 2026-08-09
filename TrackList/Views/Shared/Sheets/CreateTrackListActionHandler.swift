//
//  CreateTrackListActionHandler.swift
//  TrackList
//
//  Обрабатывает действия sheet-flow создания треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
final class CreateTrackListActionHandler {

    /// Управляет созданием треклистов.
    private let trackListsManager: any TrackListFlowManaging
    /// Показывает пользовательские сообщения.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизирует завершение формы и переход к выбору треков.
    private let router: any CreateTrackListRouting
    /// Неизменяемая идентичность конкретной формы создания.
    private let routeID: UUID

    init(
        trackListsManager: any TrackListFlowManaging,
        toastPresenter: any ToastPresenting,
        router: any CreateTrackListRouting,
        routeID: UUID = UUID()
    ) {
        self.trackListsManager = trackListsManager
        self.toastPresenter = toastPresenter
        self.router = router
        self.routeID = routeID
    }

    /// Выполняет действие sheet-flow создания треклиста.
    func handle(
        _ action: CreateTrackListAction,
        name: String
    ) {
        switch action {
        case .nameChanged:
            // Изменение поля — presentation-состояние CreateTrackListViewModel.
            return

        case .createEmpty:
            createEmptyTrackList(name: name)

        case .addTracks:
            openSelectionForCreate(name: name)

        case .cancel:
            router.dismissCreateTrackList(routeID)
        }
    }

    /// Создаёт пустой треклист и закрывает sheet.
    private func createEmptyTrackList(name: String) {
        let trimmedName = trimmedName(name)

        guard !trimmedName.isEmpty else { return }

        do {
            let created = try trackListsManager.createEmptyTrackList(withName: trimmedName)
            toastPresenter.handle(.trackListCreated(name: created.name))
        } catch let appError as AppError {
            PersistentLogger.log("CreateTrackListActionHandler: create empty tracklist failed error=\(appError)")
            toastPresenter.handle(appError)
            return
        } catch {
            PersistentLogger.log("CreateTrackListActionHandler: create empty tracklist failed error=\(error)")
            toastPresenter.handle(AppError.trackListSaveFailed)
            return
        }

        router.dismissCreateTrackList(routeID)
    }

    /// Открывает выбор треков для создания треклиста после подтверждения.
    private func openSelectionForCreate(name: String) {
        let trimmedName = trimmedName(name)

        guard !trimmedName.isEmpty else { return }

        router.presentTrackSelectionForCreate(name: trimmedName, from: routeID)
    }

    /// Возвращает название без внешних пробелов и переводов строк.
    private func trimmedName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

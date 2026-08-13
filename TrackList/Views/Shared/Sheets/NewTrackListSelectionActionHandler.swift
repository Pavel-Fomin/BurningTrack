//
//  NewTrackListSelectionActionHandler.swift
//  TrackList
//
//  Обрабатывает действия sheet-flow выбора треков для создания или пополнения треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
final class NewTrackListSelectionActionHandler {

    /// Режим применения выбранных треков.
    private let mode: NewTrackListSelectionMode
    /// Управляет созданием и пополнением треклистов.
    private let trackListsManager: any TrackListFlowManaging
    /// Показывает пользовательские сообщения.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизирует завершение sheet-flow.
    private let router: any NewTrackListSelectionRouting
    /// Неизменяемая идентичность конкретного route выбора треков.
    private let routeID: UUID

    init(
        mode: NewTrackListSelectionMode,
        trackListsManager: any TrackListFlowManaging,
        toastPresenter: any ToastPresenting,
        router: any NewTrackListSelectionRouting,
        routeID: UUID = UUID()
    ) {
        self.mode = mode
        self.trackListsManager = trackListsManager
        self.toastPresenter = toastPresenter
        self.router = router
        self.routeID = routeID
    }

    /// Закрывает только текущий route выбора без выполнения доменной операции.
    func cancel() {
        router.dismissNewTrackListSelection(routeID)
    }

    /// Показывает существующее сообщение для недоступного трека, не меняя selection и доменную операцию.
    func presentUnavailableTrack(_ track: LibraryTrack) {
        toastPresenter.handle(
            .trackUnavailable(title: track.title ?? track.fileName)
        )
    }

    /// Создаёт треклист с выбранными треками или добавляет их в существующий.
    func submit(
        selectedTracks: [LibraryTrack]
    ) async -> NewTrackListSelectionSubmissionResult {
        guard !selectedTracks.isEmpty else { return .failure(.trackListSaveFailed) }

        switch mode {
        case .create(let name):
            return createTrackList(from: selectedTracks, withName: name)

        case .append(let trackListId):
            return await appendTracks(selectedTracks, to: trackListId)
        }
    }

    /// Показывает feedback и закрывает route только пока его completion ещё актуален.
    func present(
        _ result: NewTrackListSelectionSubmissionResult
    ) async {
        switch result {
        case .created(let name):
            toastPresenter.handle(.trackListCreated(name: name))
            router.dismissNewTrackListSelection(routeID)

        case let .appended(tracks, trackListName):
            await showAddedTracksToast(tracks, trackListName: trackListName)
            router.dismissNewTrackListSelection(routeID)

        case .failure(let error):
            toastPresenter.handle(error)
        }
    }

    /// Создаёт новый треклист из выбранных треков.
    private func createTrackList(
        from selectedTracks: [LibraryTrack],
        withName name: String
    ) -> NewTrackListSelectionSubmissionResult {
        do {
            let created = try trackListsManager.createTrackList(
                from: selectedTracks,
                withName: name
            )
            return .created(created.name)
        } catch let appError as AppError {
            PersistentLogger.log("NewTrackListSelectionActionHandler: create tracklist failed error=\(appError)")
            return .failure(appError)
        } catch {
            PersistentLogger.log("NewTrackListSelectionActionHandler: create tracklist failed error=\(error)")
            return .failure(.trackListSaveFailed)
        }
    }

    /// Добавляет выбранные треки в существующий треклист.
    private func appendTracks(
        _ selectedTracks: [LibraryTrack],
        to trackListId: UUID
    ) async -> NewTrackListSelectionSubmissionResult {
        let trackListName: String

        do {
            trackListName = try trackListsManager
                .loadTrackListMetas()
                .first { $0.id == trackListId }?
                .name ?? TrackListPresentationText.defaultTrackListName
        } catch let appError as AppError {
            return .failure(appError)
        } catch {
            return .failure(.trackListLoadFailed)
        }

        do {
            _ = try trackListsManager.addTracks(
                selectedTracks,
                to: trackListId
            )
            return .appended(selectedTracks, trackListName: trackListName)
        } catch let appError as AppError {
            PersistentLogger.log("NewTrackListSelectionActionHandler: add tracks failed error=\(appError)")
            return .failure(appError)
        } catch {
            PersistentLogger.log("NewTrackListSelectionActionHandler: add tracks failed error=\(error)")
            return .failure(.trackListSaveFailed)
        }
    }

    /// Показывает один Toast по результату добавления треков.
    private func showAddedTracksToast(
        _ addedTracks: [LibraryTrack],
        trackListName: String
    ) async {
        if addedTracks.count == 1, let track = addedTracks.first {
            let event = await TrackToastEventBuilder.trackAddedToTrackList(
                track: track,
                trackListName: trackListName
            )
            toastPresenter.handle(event)
            return
        }

        toastPresenter.handle(
            .tracksAddedToTrackList(
                count: addedTracks.count,
                name: trackListName
            )
        )
    }
}

/// Результат доменной операции до presentation feedback конкретного UI-сеанса.
enum NewTrackListSelectionSubmissionResult {
    /// Создан новый треклист с нормализованным именем.
    case created(String)
    /// Выбранные треки добавлены в существующий треклист.
    case appended([LibraryTrack], trackListName: String)
    /// Операция не выполнена и должна показать существующее сообщение AppError.
    case failure(AppError)
}

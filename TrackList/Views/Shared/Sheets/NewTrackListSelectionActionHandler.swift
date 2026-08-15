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
    /// Готовит асинхронные feedback-данные без глобальных presentation side effect.
    private let feedbackPreparer: any NewTrackListSelectionFeedbackPreparing

    init(
        mode: NewTrackListSelectionMode,
        trackListsManager: any TrackListFlowManaging,
        toastPresenter: any ToastPresenting,
        router: any NewTrackListSelectionRouting,
        routeID: UUID = UUID(),
        feedbackPreparer: (any NewTrackListSelectionFeedbackPreparing)? = nil
    ) {
        self.mode = mode
        self.trackListsManager = trackListsManager
        self.toastPresenter = toastPresenter
        self.router = router
        self.routeID = routeID
        self.feedbackPreparer = feedbackPreparer
            ?? NewTrackListSelectionFeedbackPreparer()
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

    /// Готовит feedback без Toast и dismiss, чтобы ViewModel проверила session после последнего await.
    func preparePresentation(
        _ result: NewTrackListSelectionSubmissionResult
    ) async -> NewTrackListSelectionPresentation {
        switch result {
        case .created(let name):
            return .success(.trackListCreated(name: name))

        case let .appended(tracks, trackListName):
            return .success(
                await makeAddedTracksToast(
                    tracks,
                    trackListName: trackListName
                )
            )

        case .failure(let error):
            return .failure(error)
        }
    }

    /// Синхронно показывает уже подготовленный feedback после проверки актуальности session.
    func present(_ presentation: NewTrackListSelectionPresentation) {
        switch presentation {
        case .success(let event):
            toastPresenter.handle(event)
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

    /// Создаёт Toast по результату добавления, не выполняя presentation side effect до session-проверки.
    private func makeAddedTracksToast(
        _ addedTracks: [LibraryTrack],
        trackListName: String
    ) async -> ToastEvent {
        if addedTracks.count == 1, let track = addedTracks.first {
            return await feedbackPreparer.trackAddedToTrackList(
                track: track,
                trackListName: trackListName
            )
        }

        return .tracksAddedToTrackList(
            count: addedTracks.count,
            name: trackListName
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

/// Описывает подготовленный feedback, который можно синхронно показать после проверки session.
enum NewTrackListSelectionPresentation {
    /// Успешная операция показывает событие и закрывает только совпадающий route.
    case success(ToastEvent)
    /// Ошибка показывает существующий AppError и оставляет активный route открытым.
    case failure(AppError)
}

/// Подготавливает данные track-style Toast без знания о ViewModel и состоянии sheet-session.
@MainActor
protocol NewTrackListSelectionFeedbackPreparing {
    /// Формирует событие добавления одного трека, при необходимости ожидая runtime snapshot.
    func trackAddedToTrackList(
        track: LibraryTrack,
        trackListName: String
    ) async -> ToastEvent
}

/// Адаптирует существующий builder к узкой feature-зависимости, доступной для controlled XCTest.
@MainActor
struct NewTrackListSelectionFeedbackPreparer: NewTrackListSelectionFeedbackPreparing {
    /// Сохраняет каноничное построение track-style Toast через runtime snapshot.
    func trackAddedToTrackList(
        track: LibraryTrack,
        trackListName: String
    ) async -> ToastEvent {
        await TrackToastEventBuilder.trackAddedToTrackList(
            track: track,
            trackListName: trackListName
        )
    }
}

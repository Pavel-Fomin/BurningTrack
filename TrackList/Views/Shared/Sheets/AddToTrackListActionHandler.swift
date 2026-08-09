//
//  AddToTrackListActionHandler.swift
//  TrackList
//
//  Выполняет доменные команды feature-flow добавления треков в треклист.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Выполняет выбранную request-ветку и завершает sheet только после успеха.
@MainActor
final class AddToTrackListActionHandler {
    /// Управляет метаданными и добавлением Library batch в треклисты.
    private let trackListsService: any AddToTrackListTrackListsManaging
    /// Выполняет существующие ID-based и Purchased iTunes-команды.
    private let commandExecutor: any AddToTrackListExecuting
    /// Показывает пользовательские сообщения feature-flow.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизирует закрытие sheet.
    private let router: any AddToTrackListRouting
    /// Неизменяемая идентичность конкретного sheet route.
    private let routeID: UUID

    init(
        trackListsService: any AddToTrackListTrackListsManaging,
        commandExecutor: any AddToTrackListExecuting,
        toastPresenter: any ToastPresenting,
        router: any AddToTrackListRouting,
        routeID: UUID = UUID()
    ) {
        self.trackListsService = trackListsService
        self.commandExecutor = commandExecutor
        self.toastPresenter = toastPresenter
        self.router = router
        self.routeID = routeID
    }

    /// Закрывает sheet без выполнения команды добавления.
    func cancel() {
        router.dismissAddToTrackList(routeID)
    }

    /// Выполняет доменную ветку, соответствующую нормализованному источнику запроса.
    func submit(
        request: AddToTrackListRequest,
        destination: TrackListMeta
    ) async -> AddToTrackListResult {
        guard !request.trackIds.isEmpty else { return .failure }

        do {
            switch request.source {
            case .libraryTrack(let trackId):
                let result = try await commandExecutor.addTrackToTrackList(
                    trackId: trackId,
                    trackListId: destination.id
                )
                await AppCommandToastPresenter(
                    toastPresenter: toastPresenter
                ).present(result)

            case .purchasedITunes(let tracks):
                let result = try await commandExecutor.addPurchasedITunesTracksToTrackList(
                    tracks,
                    trackListId: destination.id
                )
                AppCommandToastPresenter(
                    toastPresenter: toastPresenter
                ).present(result)

            case .libraryBatch(let tracks):
                _ = try trackListsService.addTracks(
                    tracks,
                    to: destination.id
                )
                await showLibraryBatchToast(
                    tracks,
                    destination: destination
                )

            case .trackList(let trackIds):
                let result = try await commandExecutor.addTracksToTrackList(
                    trackIds: trackIds,
                    trackListId: destination.id
                )
                AppCommandToastPresenter(
                    toastPresenter: toastPresenter
                ).present(result)
            }

            router.dismissAddToTrackList(routeID)
            return .success
        } catch let appError as AppError {
            PersistentLogger.log("AddToTrackListActionHandler: add tracks failed error=\(appError)")
            AppCommandToastPresenter(
                toastPresenter: toastPresenter
            ).present(appError)
            return .failure
        } catch {
            PersistentLogger.log("AddToTrackListActionHandler: add tracks failed error=\(error)")
            toastPresenter.handle(AppError.trackListSaveFailed)
            return .failure
        }
    }

    /// Показывает сохранённый batch-toast для добавления треков из Library.
    private func showLibraryBatchToast(
        _ tracks: [LibraryTrack],
        destination: TrackListMeta
    ) async {
        let trackListName = TrackListPresentationText.title(
            for: destination.kind,
            storedName: destination.name
        )

        if tracks.count == 1, let track = tracks.first {
            let event = await TrackToastEventBuilder.trackAddedToTrackList(
                track: track,
                trackListName: trackListName
            )
            toastPresenter.handle(event)
            return
        }

        toastPresenter.handle(
            .tracksAddedToTrackList(
                count: tracks.count,
                name: trackListName
            )
        )
    }
}

/// Результат выполнения Add To TrackList для восстановления submit-состояния ViewModel.
enum AddToTrackListResult: Equatable {
    case success
    case failure
}

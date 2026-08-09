//
//  AddToTrackListFeatureFactory.swift
//  TrackList
//
//  Собирает feature-flow добавления треков в треклист.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Собирает production graph только Add To TrackList feature-flow.
@MainActor
struct AddToTrackListFeatureFactory {
    /// Загружает доступные треклисты и выполняет Library batch-операцию.
    private let trackListsService: any AddToTrackListTrackListsManaging
    /// Выполняет существующие ID-based и Purchased iTunes-команды.
    private let commandExecutor: any AddToTrackListExecuting
    /// Презентер сообщений feature-flow.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизатор закрытия sheet.
    private let router: any AddToTrackListRouting

    init(
        trackListsService: any AddToTrackListTrackListsManaging,
        commandExecutor: any AddToTrackListExecuting,
        toastPresenter: any ToastPresenting,
        router: any AddToTrackListRouting
    ) {
        self.trackListsService = trackListsService
        self.commandExecutor = commandExecutor
        self.toastPresenter = toastPresenter
        self.router = router
    }

    /// Локализует payload AppSheet и собирает готовый экран выбора destination-треклиста.
    func makeView(
        data: AddToTrackListSheetData
    ) -> AddToTrackListContainer {
        let request = AddToTrackListRequestMapper().map(data)
        let trackListsResult: Result<[TrackListMeta], Error>

        do {
            trackListsResult = .success(try trackListsService.loadTrackListMetas())
        } catch {
            trackListsResult = .failure(error)
        }

        let actionHandler = AddToTrackListActionHandler(
            trackListsService: trackListsService,
            commandExecutor: commandExecutor,
            toastPresenter: toastPresenter,
            router: router,
            routeID: data.id
        )
        let viewModel = AddToTrackListViewModel(
            request: request,
            trackListsResult: trackListsResult,
            stateBuilder: AddToTrackListStateBuilder(),
            actionHandler: actionHandler,
            toastPresenter: toastPresenter
        )

        return AddToTrackListContainer(viewModel: viewModel)
    }
}

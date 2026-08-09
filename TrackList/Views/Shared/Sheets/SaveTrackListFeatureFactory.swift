//
//  SaveTrackListFeatureFactory.swift
//  TrackList
//
//  Собирает feature-flow сохранения очереди плеера в треклист.
//
//  Created by Pavel Fomin on 04.08.2026.
//

import Foundation

/// Собирает production graph только Save TrackList feature-flow.
@MainActor
struct SaveTrackListFeatureFactory {
    /// Предоставляет актуальную очередь плеера в момент submit.
    private let queueProvider: any SaveTrackListQueueProviding
    /// Создаёт новый треклист из переданной очереди.
    private let trackListsService: any SaveTrackListCreating
    /// Презентер сообщений feature-flow.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизатор закрытия sheet.
    private let router: any SaveTrackListRouting

    init(
        queueProvider: any SaveTrackListQueueProviding,
        trackListsService: any SaveTrackListCreating,
        toastPresenter: any ToastPresenting,
        router: any SaveTrackListRouting
    ) {
        self.queueProvider = queueProvider
        self.trackListsService = trackListsService
        self.toastPresenter = toastPresenter
        self.router = router
    }

    /// Собирает Save TrackList экран, сохраняя неизменяемый payload route-контракта.
    func makeView(
        data: SaveTrackListSheetData
    ) -> SaveTrackListContainer {
        let actionHandler = SaveTrackListActionHandler(
            queueProvider: queueProvider,
            trackListsService: trackListsService,
            toastPresenter: toastPresenter,
            router: router,
            routeID: data.id
        )
        let viewModel = SaveTrackListViewModel(
            stateBuilder: SaveTrackListStateBuilder(),
            actionHandler: actionHandler
        )

        return SaveTrackListContainer(viewModel: viewModel)
    }
}

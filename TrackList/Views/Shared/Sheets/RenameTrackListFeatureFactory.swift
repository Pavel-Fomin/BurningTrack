//
//  RenameTrackListFeatureFactory.swift
//  TrackList
//
//  Собирает feature-flow переименования треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Собирает production graph только feature-flow переименования треклиста.
@MainActor
struct RenameTrackListFeatureFactory {
    /// Доменный сервис метаданных треклистов.
    private let trackListsService: any TrackListsManaging
    /// Презентер пользовательских сообщений feature-flow.
    private let toastPresenter: any ToastPresenting
    /// Маршрутизирует закрытие rename-sheet.
    private let router: any RenameTrackListRouting

    init(
        trackListsService: any TrackListsManaging,
        toastPresenter: any ToastPresenting,
        router: any RenameTrackListRouting
    ) {
        self.trackListsService = trackListsService
        self.toastPresenter = toastPresenter
        self.router = router
    }

    /// Собирает корневой экран переименования из неизменяемого sheet payload.
    func makeView(
        data: RenameTrackListSheetData
    ) -> RenameTrackListContainer {
        let actionHandler = RenameTrackListActionHandler(
            trackListsService: trackListsService,
            toastPresenter: toastPresenter,
            router: router,
            routeID: data.id
        )
        let viewModel = RenameTrackListViewModel(
            trackListId: data.trackListId,
            currentName: data.currentName,
            stateBuilder: RenameTrackListStateBuilder(),
            actionHandler: actionHandler
        )

        return RenameTrackListContainer(viewModel: viewModel)
    }
}

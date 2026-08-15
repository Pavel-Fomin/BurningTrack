//
//  TrackListFeatureFactory.swift
//  TrackList
//
//  Собирает feature graph detail-экрана одного треклиста.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Создаёт стабильный detail graph вне SwiftUI View и передаёт production-зависимости явно.
@MainActor
struct TrackListFeatureFactory {
    /// Собирает ViewModel с detail loading и готовым presentation-state.
    private let viewModelFactory: TrackListViewModelFactory
    /// Собирает detail ActionHandler с domain и presentation-зависимостями.
    private let actionHandlerFactory: TrackListFlowActionHandlerFactory
    /// Единый domain handler «Избранного» для строк detail-экрана.
    private let favoriteTrackActionHandler: FavoriteTrackActionHandler

    init(
        viewModelFactory: TrackListViewModelFactory,
        actionHandlerFactory: TrackListFlowActionHandlerFactory,
        favoriteTrackActionHandler: FavoriteTrackActionHandler
    ) {
        self.viewModelFactory = viewModelFactory
        self.actionHandlerFactory = actionHandlerFactory
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
    }

    /// Возвращает container одного destination с устойчивой identity route ID.
    func makeContainer(trackListId: UUID) -> TrackListContainer {
        TrackListContainer(
            factory: self,
            trackListId: trackListId
        )
    }

    /// Собирает ViewModel и ActionHandler ровно один раз для StateObject detail destination.
    func makeScreenStore(trackListId: UUID) -> TrackListScreenStore {
        let viewModel = viewModelFactory.make(trackListId: trackListId)
        let actionHandler = actionHandlerFactory.make(
            reader: viewModel,
            lifecycle: viewModel,
            favoriteTrackActionHandler: favoriteTrackActionHandler
        )

        return TrackListScreenStore(
            trackListId: trackListId,
            viewModel: viewModel,
            actionHandler: actionHandler
        )
    }
}

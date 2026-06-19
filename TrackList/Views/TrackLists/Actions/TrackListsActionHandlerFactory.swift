//
//  TrackListsActionHandlerFactory.swift
//  TrackList
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Собирает production action handler для master-flow списка треклистов.
@MainActor
struct TrackListsActionHandlerFactory {

    /// Создаёт production action handler для списка треклистов.
    func make(
        viewModel: TrackListsViewModel
    ) -> TrackListsActionHandler {
        TrackListsActionHandler(
            viewModel: viewModel,
            presenter: SheetManager.shared
        )
    }
}

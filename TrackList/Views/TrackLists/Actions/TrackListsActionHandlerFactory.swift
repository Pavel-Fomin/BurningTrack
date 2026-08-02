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

    /// Презентер sheet-сценариев, подготовленный Composition Root.
    private let presenter: any TrackListsPresenting

    /// Получает готовый presentation-интерфейс и не разрешает singleton самостоятельно.
    init(presenter: any TrackListsPresenting) {
        self.presenter = presenter
    }

    /// Создаёт production action handler для списка треклистов.
    func make(
        viewModel: TrackListsViewModel
    ) -> TrackListsActionHandler {
        TrackListsActionHandler(
            viewModel: viewModel,
            presenter: presenter
        )
    }
}

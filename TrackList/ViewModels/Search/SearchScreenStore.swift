//
//  SearchScreenStore.swift
//  TrackList
//
//  Хранит единый экземпляр состояния и обработчика действий экрана Search.
//  Created by Pavel Fomin on 11.08.2026.
//

import Foundation

@MainActor
final class SearchScreenStore: ObservableObject {
    /// Единственная ViewModel экранного графа Search.
    let viewModel: SearchViewModel
    /// Единственный обработчик действий экранного графа Search.
    let actionHandler: SearchActionHandler

    init(
        viewModel: SearchViewModel,
        actionHandler: SearchActionHandler
    ) {
        self.viewModel = viewModel
        self.actionHandler = actionHandler
    }
}

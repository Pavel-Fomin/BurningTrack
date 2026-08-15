//
//  LibraryScreenStore.swift
//  TrackList
//
//  Удерживает корневой graph feature фонотеки.
//
//  Created by Pavel Fomin on 14.08.2026.
//

import Combine

/// Хранит navigation и master flow фонотеки, созданные единожды для корневого экрана.
@MainActor
final class LibraryScreenStore: ObservableObject {
    /// ViewModel владеет маршрутом и состоянием разделов коллекции.
    let viewModel: LibraryScreenViewModel
    /// ViewModel владеет состоянием папок и presentation intent picker-а.
    let masterViewModel: LibraryMasterViewModel
    /// Handler корневых folder-действий живёт столько же, сколько и feature graph.
    let masterActionHandler: LibraryMasterActionHandler

    init(
        viewModel: LibraryScreenViewModel,
        masterViewModel: LibraryMasterViewModel,
        masterActionHandler: LibraryMasterActionHandler
    ) {
        self.viewModel = viewModel
        self.masterViewModel = masterViewModel
        self.masterActionHandler = masterActionHandler
    }
}

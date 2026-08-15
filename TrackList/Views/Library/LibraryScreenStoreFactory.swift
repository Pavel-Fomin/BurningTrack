//
//  LibraryScreenStoreFactory.swift
//  TrackList
//
//  Собирает устойчивый корневой graph feature фонотеки.
//
//  Created by Pavel Fomin on 14.08.2026.
//

import Foundation

/// Изолирует создание root ViewModel и master ActionHandler от SwiftUI-представления.
@MainActor
struct LibraryScreenStoreFactory {
    /// Создаёт navigation ViewModel корня фонотеки.
    private let screenViewModelFactory: LibraryScreenViewModelFactory
    /// Создаёт ViewModel секции папок.
    private let masterViewModelFactory: LibraryMasterViewModelFactory
    /// Создаёт master ActionHandler после появления его output.
    private let masterActionHandlerFactory: LibraryMasterActionHandlerFactory

    init(
        screenViewModelFactory: LibraryScreenViewModelFactory,
        masterViewModelFactory: LibraryMasterViewModelFactory,
        masterActionHandlerFactory: LibraryMasterActionHandlerFactory
    ) {
        self.screenViewModelFactory = screenViewModelFactory
        self.masterViewModelFactory = masterViewModelFactory
        self.masterActionHandlerFactory = masterActionHandlerFactory
    }

    /// Собирает root graph один раз из явных feature-зависимостей.
    func make() -> LibraryScreenStore {
        let viewModel = screenViewModelFactory.make()
        let masterViewModel = masterViewModelFactory.make()
        let masterActionHandler = masterActionHandlerFactory.make(
            output: masterViewModel
        )

        return LibraryScreenStore(
            viewModel: viewModel,
            masterViewModel: masterViewModel,
            masterActionHandler: masterActionHandler
        )
    }
}

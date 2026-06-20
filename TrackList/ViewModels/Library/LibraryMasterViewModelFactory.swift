//
//  LibraryMasterViewModelFactory.swift
//  TrackList
//
//  Фабрика ViewModel корневого экрана фонотеки.
//  Собирает production-зависимости без DI-контейнера.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

@MainActor
enum LibraryMasterViewModelFactory {
    // MARK: - Make

    static func make() -> LibraryMasterViewModel {
        make(
            manager: .shared,
            stateBuilder: LibraryMasterScreenStateBuilder()
        )
    }

    static func make(
        manager: MusicLibraryManager,
        stateBuilder: LibraryMasterScreenStateBuilder = LibraryMasterScreenStateBuilder()
    ) -> LibraryMasterViewModel {
        LibraryMasterViewModel(
            manager: manager,
            stateBuilder: stateBuilder
        )
    }
}

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
            settingsManager: AppSettingsManager.shared,
            stateBuilder: LibraryMasterScreenStateBuilder()
        )
    }

    static func make(
        manager: MusicLibraryManager,
        settingsManager: (any SettingsManaging)? = nil,
        stateBuilder: LibraryMasterScreenStateBuilder = LibraryMasterScreenStateBuilder()
    ) -> LibraryMasterViewModel {
        // Singleton берём внутри MainActor-функции, чтобы не использовать actor-isolated значение в default argument.
        let resolvedSettingsManager = settingsManager ?? AppSettingsManager.shared

        return LibraryMasterViewModel(
            manager: manager,
            settingsManager: resolvedSettingsManager,
            stateBuilder: stateBuilder
        )
    }
}

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
            toastPresenter: ToastManager.shared,
            stateBuilder: LibraryMasterScreenStateBuilder()
        )
    }

    static func make(
        manager: MusicLibraryManager,
        settingsManager: (any SettingsManaging)? = nil,
        toastPresenter: (any ToastPresenting)? = nil,
        stateBuilder: LibraryMasterScreenStateBuilder = LibraryMasterScreenStateBuilder()
    ) -> LibraryMasterViewModel {
        // Singleton берём внутри MainActor-функции, чтобы не использовать actor-isolated значение в default argument.
        let resolvedSettingsManager = settingsManager ?? AppSettingsManager.shared
        // Toast-презентер нужен ViewModel только для ошибок сохранения порядка папок.
        let resolvedToastPresenter = toastPresenter ?? ToastManager.shared

        return LibraryMasterViewModel(
            manager: manager,
            settingsManager: resolvedSettingsManager,
            toastPresenter: resolvedToastPresenter,
            stateBuilder: stateBuilder
        )
    }
}

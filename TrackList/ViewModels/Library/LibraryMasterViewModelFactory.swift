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
struct LibraryMasterViewModelFactory {

    /// Менеджер фонотеки, подготовленный Composition Root.
    private let manager: MusicLibraryManager
    /// Настройки фонотеки, подготовленные Composition Root.
    private let settingsManager: any SettingsManaging
    /// Презентер ошибок фонотеки, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
    /// Builder presentation-состояния, подготовленный Composition Root.
    private let stateBuilder: LibraryMasterScreenStateBuilder

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        manager: MusicLibraryManager,
        settingsManager: any SettingsManaging,
        toastPresenter: any ToastPresenting,
        stateBuilder: LibraryMasterScreenStateBuilder
    ) {
        self.manager = manager
        self.settingsManager = settingsManager
        self.toastPresenter = toastPresenter
        self.stateBuilder = stateBuilder
    }

    /// Собирает ViewModel без доступа к глобальному графу зависимостей.
    func make() -> LibraryMasterViewModel {
        return LibraryMasterViewModel(
            manager: manager,
            settingsManager: settingsManager,
            toastPresenter: toastPresenter,
            stateBuilder: stateBuilder
        )
    }
}

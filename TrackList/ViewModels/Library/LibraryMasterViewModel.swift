//
//  LibraryMasterViewModel.swift
//  TrackList
//
//  ViewModel корневого экрана фонотеки.
//  Наблюдает MusicLibraryManager и публикует готовое состояние для View.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Combine
import Foundation

@MainActor
final class LibraryMasterViewModel: ObservableObject, LibraryMasterActionOutput {

    /// Готовое состояние корневого экрана фонотеки.
    @Published private(set) var screenState = LibraryMasterScreenState(
        accessState: .booting,
        folders: [],
        showsPurchasedITunesSource: AppSettings.defaultValue.visible.library.isPurchasedITunesSourceVisible,
        isEmpty: true,
        detachAlert: nil
    )

    /// Папка, ожидающая подтверждения открепления.
    private(set) var pendingDetachFolder: LibraryFolder?

    /// Менеджер фонотеки, из которого собирается состояние.
    private let manager: MusicLibraryManager
    /// Менеджер настроек управляет видимостью виртуальных источников фонотеки.
    private let settingsManager: any SettingsManaging
    /// Builder состояния экрана.
    private let stateBuilder: LibraryMasterScreenStateBuilder
    /// Подписки на изменения менеджера.
    private var cancellables = Set<AnyCancellable>()

    init(
        manager: MusicLibraryManager,
        settingsManager: any SettingsManaging,
        stateBuilder: LibraryMasterScreenStateBuilder = LibraryMasterScreenStateBuilder()
    ) {
        self.manager = manager
        self.settingsManager = settingsManager
        self.stateBuilder = stateBuilder

        observeManager()
        observeSettings()
        refreshState()
    }

    /// Пересобирает состояние экрана из актуального состояния MusicLibraryManager.
    func refreshState() {
        screenState = stateBuilder.build(
            manager: manager,
            settings: settingsManager.settings,
            pendingDetachFolder: pendingDetachFolder
        )
    }

    /// Запоминает папку, для которой нужно показать подтверждение открепления.
    func setPendingDetachFolder(
        _ folder: LibraryFolder
    ) {
        pendingDetachFolder = folder
        refreshState()
    }

    /// Сбрасывает папку, ожидающую подтверждения открепления.
    func clearPendingDetachFolder() {
        pendingDetachFolder = nil
        refreshState()
    }

    /// Подписывается на изменения фонотеки и синхронизирует экранное состояние.
    private func observeManager() {
        manager.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshState()
                }
            }
            .store(in: &cancellables)
    }

    /// Подписывается на настройки, чтобы корень фонотеки скрывал или показывал iTunes row без перезапуска.
    private func observeSettings() {
        settingsManager.settingsPublisher
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshState()
                }
            }
            .store(in: &cancellables)
    }
}

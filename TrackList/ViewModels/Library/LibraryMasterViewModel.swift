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
final class LibraryMasterViewModel: ObservableObject {

    /// Готовое состояние корневого экрана фонотеки.
    @Published private(set) var screenState = LibraryMasterScreenState(
        accessState: .booting,
        folders: [],
        isEmpty: true,
        detachAlert: nil
    )

    /// Папка, ожидающая подтверждения открепления.
    private(set) var pendingDetachFolder: LibraryFolder?

    /// Менеджер фонотеки, из которого собирается состояние.
    private let manager: MusicLibraryManager
    /// Builder состояния экрана.
    private let stateBuilder: LibraryMasterScreenStateBuilder
    /// Подписки на изменения менеджера.
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.manager = MusicLibraryManager.shared
        self.stateBuilder = LibraryMasterScreenStateBuilder()

        observeManager()
        refreshState()
    }

    init(
        manager: MusicLibraryManager,
        stateBuilder: LibraryMasterScreenStateBuilder = LibraryMasterScreenStateBuilder()
    ) {
        self.manager = manager
        self.stateBuilder = stateBuilder

        observeManager()
        refreshState()
    }

    /// Пересобирает состояние экрана из актуального состояния MusicLibraryManager.
    func refreshState() {
        screenState = stateBuilder.build(
            manager: manager,
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
}

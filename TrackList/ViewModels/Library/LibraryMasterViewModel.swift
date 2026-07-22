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
import SwiftUI

@MainActor
final class LibraryMasterViewModel: ObservableObject, LibraryMasterActionOutput {

    /// Готовое состояние корневого экрана фонотеки.
    @Published private(set) var screenState = LibraryMasterScreenState(
        accessState: .booting,
        folders: [],
        showsPurchasedITunesSource: AppSettings.defaultValue.visible.library.isPurchasedITunesSourceVisible,
        isEmpty: true,
        folderContainsPlayingTrack: false
    )

    /// Папка, ожидающая подтверждения открепления.
    private(set) var pendingDetachFolder: LibraryFolder?

    /// Менеджер фонотеки, из которого собирается состояние.
    private let manager: MusicLibraryManager
    /// Менеджер настроек управляет видимостью виртуальных источников фонотеки.
    private let settingsManager: any SettingsManaging
    /// Показывает пользовательские сообщения об ошибках.
    private let toastPresenter: any ToastPresenting
    /// Builder состояния экрана.
    private let stateBuilder: LibraryMasterScreenStateBuilder
    /// Подписки на изменения менеджера.
    private var cancellables = Set<AnyCancellable>()

    init(
        manager: MusicLibraryManager,
        settingsManager: any SettingsManaging,
        toastPresenter: any ToastPresenting,
        stateBuilder: LibraryMasterScreenStateBuilder = LibraryMasterScreenStateBuilder()
    ) {
        self.manager = manager
        self.settingsManager = settingsManager
        self.toastPresenter = toastPresenter
        self.stateBuilder = stateBuilder

        observeManager()
        observeSettings()
        refreshState()
    }

    /// Пересобирает состояние экрана из актуального состояния MusicLibraryManager.
    func refreshState() {
        refreshState(using: settingsManager.settings)
    }

    /// Использует полученный снимок настроек, чтобы состояние не зависело от порядка публикации @Published.
    private func refreshState(using settings: AppSettings) {
        screenState = stateBuilder.build(
            manager: manager,
            settings: settings,
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

    /// Сохраняет новый ручной порядок прикреплённых папок в SQLite и обновляет состояние экрана.
    func moveFolder(from source: IndexSet, to destination: Int) {
        Task { @MainActor in
            var updatedFolders = manager.attachedFolders
            updatedFolders.move(fromOffsets: source, toOffset: destination)

            do {
                try await manager.saveAttachedFoldersOrder(updatedFolders.map(\.id))
                manager.replaceAttachedFolders(with: updatedFolders)
                refreshState()
            } catch {
                toastPresenter.handle(
                    .operationFailed(
                        message: LibraryPresentationText.folderOrderSaveFailedMessage
                    )
                )
                refreshState()
            }
        }
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

    /// Подписывается только на настройку, которая меняет строки корня фонотеки.
    private func observeSettings() {
        settingsManager.settingsPublisher
            .removeDuplicates { previous, current in
                previous.visible.library.isPurchasedITunesSourceVisible == current.visible.library.isPurchasedITunesSourceVisible
            }
            .sink { [weak self] settings in
                // Используем payload Publisher, чтобы не прочитать предыдущее значение @Published.
                self?.refreshState(using: settings)
            }
            .store(in: &cancellables)
    }
}

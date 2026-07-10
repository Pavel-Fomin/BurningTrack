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
        detachAlert: nil,
        selectedSortMode: nil,
        sortModeCaption: nil
    )
    /// Последняя сортировка, выбранная через меню; nil означает ручной порядок.
    @Published private(set) var sortMode: LibraryFoldersSortMode?
    /// Последний выбранный режим корня фонотеки.
    @Published private(set) var rootDisplayMode: LibraryRootDisplayMode

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
        self.sortMode = settingsManager.settings.internalSettings.libraryFoldersSortMode
        self.rootDisplayMode = settingsManager.settings.internalSettings.libraryRootDisplayMode

        observeManager()
        observeSettings()
        refreshState()
    }

    /// Пересобирает состояние экрана из актуального состояния MusicLibraryManager.
    func refreshState() {
        screenState = stateBuilder.build(
            manager: manager,
            settings: settingsManager.settings,
            pendingDetachFolder: pendingDetachFolder,
            selectedSortMode: sortMode
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

    /// Переключает режим корня и сохраняет новое значение через SettingsManaging.
    func toggleDisplayMode() {
        let previousMode = rootDisplayMode
        let newMode = previousMode.toggled
        rootDisplayMode = newMode

        do {
            try settingsManager.setLibraryRootDisplayMode(newMode)
        } catch {
            rootDisplayMode = previousMode
            toastPresenter.handle(
                .operationFailed(message: "Не удалось сохранить режим отображения фонотеки")
            )
        }
    }

    /// Сортирует прикреплённые папки, сохраняет новый фактический порядок в SQLite и показывает caption режима.
    func setSortMode(_ mode: LibraryFoldersSortMode) {
        Task { @MainActor in
            let previousSortMode = sortMode
            let updatedFolders = await manager.sortedAttachedFolders(by: mode)

            do {
                try settingsManager.setLibraryFoldersSortMode(mode)
                try await manager.saveAttachedFoldersOrder(updatedFolders.map(\.id))
                manager.replaceAttachedFolders(with: updatedFolders)
                sortMode = mode
                refreshState()
            } catch {
                try? settingsManager.setLibraryFoldersSortMode(previousSortMode)
                toastPresenter.handle(
                    .operationFailed(message: "Не удалось сохранить порядок папок")
                )
                refreshState()
            }
        }
    }

    /// Сохраняет новый ручной порядок прикреплённых папок в SQLite и обновляет состояние экрана.
    func moveFolder(from source: IndexSet, to destination: Int) {
        Task { @MainActor in
            let previousSortMode = sortMode
            var updatedFolders = manager.attachedFolders
            updatedFolders.move(fromOffsets: source, toOffset: destination)

            do {
                try settingsManager.setLibraryFoldersSortMode(nil)
                try await manager.saveAttachedFoldersOrder(updatedFolders.map(\.id))
                manager.replaceAttachedFolders(with: updatedFolders)
                sortMode = nil
                refreshState()
            } catch {
                try? settingsManager.setLibraryFoldersSortMode(previousSortMode)
                toastPresenter.handle(
                    .operationFailed(message: "Не удалось сохранить порядок папок")
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

    /// Подписывается на настройки, чтобы корень фонотеки скрывал или показывал iTunes row без перезапуска.
    private func observeSettings() {
        settingsManager.settingsPublisher
            .sink { [weak self] settings in
                Task { @MainActor in
                    self?.sortMode = settings.internalSettings.libraryFoldersSortMode
                    self?.refreshState()
                }
            }
            .store(in: &cancellables)
    }
}

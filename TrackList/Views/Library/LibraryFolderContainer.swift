//
//  LibraryFolderContainer.swift
//  TrackList
//
//  Контейнер экрана папки фонотеки.
//  Создаёт и удерживает LibraryFolderViewModel через StateObject,
//  чтобы ViewModel не пересоздавалась при каждом пересчёте SwiftUI.
//
//  Created by Pavel Fomin on 29.03.2026.
//

import SwiftUI

struct LibraryFolderContainer: View {

    // MARK: - Входные данные

    let folder: LibraryFolder
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    /// Готовая фабрика ViewModel папки с явными production-зависимостями.
    let viewModelFactory: LibraryFolderViewModelFactory
    /// Точка сборки screen-local объектов списка треков папки.
    let tracksScreenFactory: LibraryTracksScreenFactory
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    @Binding var selectionActionSender: (any LibraryTracksActionSending)?

    // MARK: - Инициализация

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        viewModelFactory: LibraryFolderViewModelFactory,
        tracksScreenFactory: LibraryTracksScreenFactory,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>,
        selectionActionSender: Binding<(any LibraryTracksActionSending)?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.viewModelFactory = viewModelFactory
        self.tracksScreenFactory = tracksScreenFactory
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
    }

    // MARK: - Интерфейс

    var body: some View {
        LibraryFolderContent(
            folder: folder,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            viewModelFactory: viewModelFactory,
            tracksScreenFactory: tracksScreenFactory,
            selectionActionBarConfig: $selectionActionBarConfig,
            selectionActionSender: $selectionActionSender
        )
        .id(folder.id)
    }
}

private struct LibraryFolderContent: View {

    // MARK: - Входные данные

    let folder: LibraryFolder
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    /// Готовая фабрика ViewModel папки с явными production-зависимостями.
    let viewModelFactory: LibraryFolderViewModelFactory
    let tracksScreenFactory: LibraryTracksScreenFactory
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    @Binding var selectionActionSender: (any LibraryTracksActionSending)?

    // MARK: - ViewModel

    /// ViewModel живёт ровно пока существует destination папки; смена `folder.id` создаёт новый graph через внешний `.id`.
    @StateObject private var viewModel: LibraryFolderViewModel

    // MARK: - Инициализация

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest?,
        onRevealHandled: @escaping (UUID) -> Void,
        viewModelFactory: LibraryFolderViewModelFactory,
        tracksScreenFactory: LibraryTracksScreenFactory,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>,
        selectionActionSender: Binding<(any LibraryTracksActionSending)?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.viewModelFactory = viewModelFactory
        self.tracksScreenFactory = tracksScreenFactory
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
        // Сохраняем Binding локально, чтобы action handler очищал текущую панель выбора.
        let selectionActionBarConfig = selectionActionBarConfig
        self._viewModel = StateObject(
            wrappedValue: viewModelFactory.make(
                folder: folder,
                clearSelectionActionBar: {
                    selectionActionBarConfig.wrappedValue = nil
                }
            )
        )
    }

    // MARK: - Интерфейс

    var body: some View {
        LibraryFolderView(
            state: viewModel.screenState,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            tracksScreenFactory: tracksScreenFactory,
            selectionActionBarConfig: $selectionActionBarConfig,
            selectionActionSender: $selectionActionSender,
            onAction: viewModel.handle
        )
    }
}

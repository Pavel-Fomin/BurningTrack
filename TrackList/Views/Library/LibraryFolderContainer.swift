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
    let exportProgressViewModel: ExportProgressViewModel
    /// Готовая фабрика ViewModel папки с явными production-зависимостями.
    let viewModelFactory: LibraryFolderViewModelFactory
    /// Точка сборки screen-local объектов списка треков папки.
    let tracksScreenFactory: LibraryTracksScreenFactory
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    @Binding var selectionActionSender: (any LibraryTracksActionSending)?

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        exportProgressViewModel: ExportProgressViewModel,
        viewModelFactory: LibraryFolderViewModelFactory,
        tracksScreenFactory: LibraryTracksScreenFactory,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>,
        selectionActionSender: Binding<(any LibraryTracksActionSending)?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.exportProgressViewModel = exportProgressViewModel
        self.viewModelFactory = viewModelFactory
        self.tracksScreenFactory = tracksScreenFactory
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
    }

    // MARK: - UI

    var body: some View {
        LibraryFolderContent(
            folder: folder,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            exportProgressViewModel: exportProgressViewModel,
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
    let exportProgressViewModel: ExportProgressViewModel
    /// Готовая фабрика ViewModel папки с явными production-зависимостями.
    let viewModelFactory: LibraryFolderViewModelFactory
    let tracksScreenFactory: LibraryTracksScreenFactory
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    @Binding var selectionActionSender: (any LibraryTracksActionSending)?

    // MARK: - ViewModel

    @StateObject private var viewModel: LibraryFolderViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest?,
        onRevealHandled: @escaping (UUID) -> Void,
        exportProgressViewModel: ExportProgressViewModel,
        viewModelFactory: LibraryFolderViewModelFactory,
        tracksScreenFactory: LibraryTracksScreenFactory,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>,
        selectionActionSender: Binding<(any LibraryTracksActionSending)?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.exportProgressViewModel = exportProgressViewModel
        self.viewModelFactory = viewModelFactory
        self.tracksScreenFactory = tracksScreenFactory
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
        // Сохраняем Binding локально, чтобы action handler очищал текущую панель выбора.
        let selectionActionBarConfig = selectionActionBarConfig
        self._viewModel = StateObject(
            wrappedValue: viewModelFactory.make(
                folder: folder,
                exportProgressViewModel: exportProgressViewModel,
                clearSelectionActionBar: {
                    selectionActionBarConfig.wrappedValue = nil
                }
            )
        )
    }

    // MARK: - UI

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

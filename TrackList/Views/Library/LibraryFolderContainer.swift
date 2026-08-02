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
    /// Реактивное playback-состояние для строк папки.
    let playbackStateProvider: any PlaybackStateProviding
    /// Команды запуска строк папки.
    let playbackController: any TrackPlaybackControlling
    /// Published-состояние «Избранного» для строк папки.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Проверка занятости файлов для массового переименования.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Общий обработчик переименования файлов.
    let renameActionHandler: TrackFileRenameActionHandler
    let exportProgressViewModel: ExportProgressViewModel
    /// Единый обработчик «Избранного» передаётся в содержимое папки.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Готовая фабрика ViewModel папки с явными production-зависимостями.
    let viewModelFactory: LibraryFolderViewModelFactory
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest? = nil,
        onRevealHandled: @escaping (UUID) -> Void = { _ in },
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        fileBusyChecker: any TrackFileBusyChecking,
        renameActionHandler: TrackFileRenameActionHandler,
        exportProgressViewModel: ExportProgressViewModel,
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        viewModelFactory: LibraryFolderViewModelFactory,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.fileBusyChecker = fileBusyChecker
        self.renameActionHandler = renameActionHandler
        self.exportProgressViewModel = exportProgressViewModel
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.viewModelFactory = viewModelFactory
        self._selectionActionBarConfig = selectionActionBarConfig
    }

    // MARK: - UI

    var body: some View {
        LibraryFolderContent(
            folder: folder,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            fileBusyChecker: fileBusyChecker,
            renameActionHandler: renameActionHandler,
            exportProgressViewModel: exportProgressViewModel,
            favoriteTrackActionHandler: favoriteTrackActionHandler,
            viewModelFactory: viewModelFactory,
            selectionActionBarConfig: $selectionActionBarConfig
        )
        .id(folder.id)
    }
}

private struct LibraryFolderContent: View {

    // MARK: - Входные данные

    let folder: LibraryFolder
    let revealRequest: LibraryRevealRequest?
    let onRevealHandled: (UUID) -> Void
    /// Реактивное playback-состояние для строк папки.
    let playbackStateProvider: any PlaybackStateProviding
    /// Команды запуска строк папки.
    let playbackController: any TrackPlaybackControlling
    /// Published-состояние «Избранного» для строк папки.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Проверка занятости файлов для массового переименования.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Общий обработчик переименования файлов.
    let renameActionHandler: TrackFileRenameActionHandler
    let exportProgressViewModel: ExportProgressViewModel
    /// Единый обработчик «Избранного» передаётся в экран папки.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Готовая фабрика ViewModel папки с явными production-зависимостями.
    let viewModelFactory: LibraryFolderViewModelFactory
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?

    // MARK: - ViewModel

    @StateObject private var viewModel: LibraryFolderViewModel

    // MARK: - Init

    init(
        folder: LibraryFolder,
        revealRequest: LibraryRevealRequest?,
        onRevealHandled: @escaping (UUID) -> Void,
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        fileBusyChecker: any TrackFileBusyChecking,
        renameActionHandler: TrackFileRenameActionHandler,
        exportProgressViewModel: ExportProgressViewModel,
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        viewModelFactory: LibraryFolderViewModelFactory,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>
    ) {
        self.folder = folder
        self.revealRequest = revealRequest
        self.onRevealHandled = onRevealHandled
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.fileBusyChecker = fileBusyChecker
        self.renameActionHandler = renameActionHandler
        self.exportProgressViewModel = exportProgressViewModel
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.viewModelFactory = viewModelFactory
        self._selectionActionBarConfig = selectionActionBarConfig
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
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            fileBusyChecker: fileBusyChecker,
            renameActionHandler: renameActionHandler,
            favoriteTrackActionHandler: favoriteTrackActionHandler,
            selectionActionBarConfig: $selectionActionBarConfig,
            onAction: viewModel.handle
        )
    }
}

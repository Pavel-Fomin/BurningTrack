//
//  LibraryFolderActionHandler.swift
//  TrackList
//
//  Обрабатывает действия экрана папки фонотеки.
//  Здесь находятся навигация и побочные эффекты, а не во View.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

@MainActor
final class LibraryFolderActionHandler {
    // MARK: - Dependencies

    private let navigationCoordinator: NavigationCoordinator
    private let clearSelectionActionBar: @MainActor () -> Void
    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling
    /// Семантическая дочерняя папка экспортируемого содержимого.
    private let exportFolder: ExportFolder

    // MARK: - Init

    init(
        navigationCoordinator: NavigationCoordinator,
        exportRequestHandler: any ExportRequestHandling,
        exportFolder: ExportFolder,
        clearSelectionActionBar: @escaping @MainActor () -> Void
    ) {
        self.navigationCoordinator = navigationCoordinator
        self.exportRequestHandler = exportRequestHandler
        self.exportFolder = exportFolder
        self.clearSelectionActionBar = clearSelectionActionBar
    }

    // MARK: - Handle

    func handle(_ action: LibraryFolderAction) {
        switch action {
        case .appeared:
            clearSelectionActionBar()
        case .subfolderTapped(let subfolder):
            navigationCoordinator.pushFolder(subfolder.url.libraryFolderId)
        case .exportTracks(let libraryTracks):
            exportTracks(libraryTracks)
        }
    }

    // MARK: - Export

    /// Запускает общий экспорт треков текущей папки без нумерации имён файлов.
    private func exportTracks(_ libraryTracks: [LibraryTrack]) {
        // Секции уже собраны в текущем порядке отображения, поэтому не пересортировываем треки.
        let tracks = libraryTracks.map(Track.init(libraryTrack:))
        exportRequestHandler.startExport(
            ExportRequest(
                tracks: tracks,
                exportFolder: exportFolder,
                fileNamingMode: .original
            )
        )
    }
}

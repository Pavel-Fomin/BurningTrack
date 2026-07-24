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
    /// Глобальный владелец прогресса и жизненного цикла экспорта.
    private let exportProgressViewModel: ExportProgressViewModel
    /// Предоставляет presenter системного picker-а папки назначения.
    private let viewControllerProvider: any ViewControllerProviding
    /// Показывает ошибку, если системный picker нельзя презентовать.
    private let toastPresenter: any ToastPresenting
    /// Семантическая дочерняя папка экспортируемого содержимого.
    private let exportFolder: ExportFolder

    // MARK: - Init

    init(
        navigationCoordinator: NavigationCoordinator,
        exportProgressViewModel: ExportProgressViewModel,
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting,
        exportFolder: ExportFolder,
        clearSelectionActionBar: @escaping @MainActor () -> Void
    ) {
        self.navigationCoordinator = navigationCoordinator
        self.exportProgressViewModel = exportProgressViewModel
        self.viewControllerProvider = viewControllerProvider
        self.toastPresenter = toastPresenter
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
        guard libraryTracks.isEmpty == false else { return }

        guard let presenter = viewControllerProvider.topViewController() else {
            toastPresenter.handle(.presenterUnavailable)
            return
        }

        // Секции уже собраны в текущем порядке отображения, поэтому не пересортировываем треки.
        let tracks = libraryTracks.map(Track.init(libraryTrack:))
        exportProgressViewModel.startExport(
            tracks: tracks,
            exportFolder: exportFolder,
            fileNamingMode: .original,
            presenter: presenter
        )
    }
}

//
//  LibraryCollectionTracksActionHandler.swift
//  TrackList
//
//  Обрабатывает экспорт треков выбранного значения музыкальной коллекции.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Запускает экспорт видимых треков выбранного значения музыкальной коллекции.
@MainActor
final class LibraryCollectionTracksActionHandler {

    // MARK: - Dependencies

    /// Типизированный источник хранит отображаемое имя выбранного значения для экспорта.
    private let source: LibraryTrackListSource
    /// Глобальный владелец прогресса и жизненного цикла экспорта.
    private let exportProgressViewModel: ExportProgressViewModel
    /// Предоставляет presenter системного picker-а папки назначения.
    private let viewControllerProvider: any ViewControllerProviding
    /// Показывает ошибку, если системный picker нельзя презентовать.
    private let toastPresenter: any ToastPresenting

    // MARK: - Init

    init(
        source: LibraryTrackListSource,
        exportProgressViewModel: ExportProgressViewModel,
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting
    ) {
        self.source = source
        self.exportProgressViewModel = exportProgressViewModel
        self.viewControllerProvider = viewControllerProvider
        self.toastPresenter = toastPresenter
    }

    // MARK: - Handle

    func handle(_ action: LibraryCollectionTracksAction) {
        switch action {
        case .exportTracks(let libraryTracks):
            exportTracks(libraryTracks)
        }
    }

    // MARK: - Export

    /// Запускает экспорт треков выбранного значения без изменения текущего порядка строк.
    private func exportTracks(_ libraryTracks: [LibraryTrack]) {
        guard source.isCollectionValue,
              let exportFolderName = source.exportFolderName,
              libraryTracks.isEmpty == false else {
            return
        }

        guard let presenter = viewControllerProvider.topViewController() else {
            toastPresenter.handle(.presenterUnavailable)
            return
        }

        let tracks = libraryTracks.map(Track.init(libraryTrack:))
        exportProgressViewModel.startExport(
            tracks: tracks,
            exportFolderName: exportFolderName,
            fileNamingMode: .original,
            presenter: presenter
        )
    }
}

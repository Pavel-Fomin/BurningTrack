//
//  LibraryAllTracksActionHandler.swift
//  TrackList
//
//  Обрабатывает экспорт общего списка треков фонотеки.
//
//  Created by Pavel Fomin on 20.07.2026.
//

import Foundation

/// Запускает общий экспорт видимых треков корневого режима «Треки».
@MainActor
final class LibraryAllTracksActionHandler {

    // MARK: - Dependencies

    /// Глобальный владелец прогресса и жизненного цикла экспорта.
    private let exportProgressViewModel: ExportProgressViewModel
    /// Предоставляет presenter системного picker-а папки назначения.
    private let viewControllerProvider: any ViewControllerProviding
    /// Показывает ошибку, если системный picker нельзя презентовать.
    private let toastPresenter: any ToastPresenting

    // MARK: - Init

    init(
        exportProgressViewModel: ExportProgressViewModel,
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting
    ) {
        self.exportProgressViewModel = exportProgressViewModel
        self.viewControllerProvider = viewControllerProvider
        self.toastPresenter = toastPresenter
    }

    // MARK: - Handle

    func handle(_ action: LibraryAllTracksAction) {
        switch action {
        case .exportTracks(let libraryTracks):
            exportTracks(libraryTracks)
        }
    }

    // MARK: - Export

    /// Запускает экспорт общего списка треков без нумерации имён файлов.
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
            exportFolder: .libraryTracks,
            fileNamingMode: .original,
            presenter: presenter
        )
    }
}

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
    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling

    // MARK: - Init

    init(
        source: LibraryTrackListSource,
        exportRequestHandler: any ExportRequestHandling
    ) {
        self.source = source
        self.exportRequestHandler = exportRequestHandler
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
              let exportFolder = source.exportFolder else {
            return
        }

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

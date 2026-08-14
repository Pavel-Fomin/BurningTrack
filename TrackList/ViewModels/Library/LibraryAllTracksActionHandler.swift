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

    // MARK: - Зависимости

    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling

    // MARK: - Инициализация

    init(
        exportRequestHandler: any ExportRequestHandling
    ) {
        self.exportRequestHandler = exportRequestHandler
    }

    // MARK: - Обработка

    func handle(_ action: LibraryAllTracksAction) {
        switch action {
        case .exportTracks(let libraryTracks):
            exportTracks(libraryTracks)
        }
    }

    // MARK: - Экспорт

    /// Запускает экспорт общего списка треков без нумерации имён файлов.
    private func exportTracks(_ libraryTracks: [LibraryTrack]) {
        // Секции уже собраны в текущем порядке отображения, поэтому не пересортировываем треки.
        let tracks = libraryTracks.map(Track.init(libraryTrack:))
        exportRequestHandler.startExport(
            ExportRequest(
                tracks: tracks,
                exportFolder: .libraryTracks,
                fileNamingMode: .original
            )
        )
    }
}

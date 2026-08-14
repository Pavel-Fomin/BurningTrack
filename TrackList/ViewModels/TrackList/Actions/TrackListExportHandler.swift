//
//  TrackListExportHandler.swift
//  TrackList
//
//  Направляет подготовленные данные треклиста в глобальный export-flow.
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает export-flow одного треклиста.
@MainActor
final class TrackListExportHandler {

    /// Источник read-only данных одного треклиста.
    private let reader: any TrackListReading

    /// Типизированный вход в глобальный Export-feature.
    private let exportRequestHandler: any ExportRequestHandling

    /// Создаёт обработчик export-flow одного треклиста.
    init(
        reader: any TrackListReading,
        exportRequestHandler: any ExportRequestHandling
    ) {
        self.reader = reader
        self.exportRequestHandler = exportRequestHandler
    }

    /// Экспортирует треки текущего треклиста.
    func exportTracks() {
        // Экран передаёт только данные текущего треклиста без знания picker-а.
        exportRequestHandler.startExport(
            ExportRequest(
                tracks: reader.tracks,
                exportFolder: .named(reader.name),
                fileNamingMode: .numbered
            )
        )
    }
}

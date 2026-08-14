//
//  TrackExporting.swift
//  TrackList
//
//  Объявляет capability запуска и отмены глобального export-flow.
//
//  Created by Pavel Fomin on 18.06.2026.
//

/// Выполняет экспорт треков.
@MainActor
protocol TrackExporting {
    /// Выполняет готовый экспортный запрос.
    @discardableResult
    func exportTracks(
        _ request: ExportRequest,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportSummary

    /// Отменяет системный выбор назначения или текущее копирование.
    func cancelCurrentExport()
}

//
//  TrackExporting.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import UIKit

/// Выполняет экспорт треков.
@MainActor
protocol TrackExporting {
    /// Выбирает папку и экспортирует треки напрямую в неё.
    @discardableResult
    func exportTracks(
        _ tracks: [Track],
        exportFolderName: String,
        presenter: UIViewController,
        onProgress: @escaping ExportProgressHandler
    ) async throws -> ExportManager.ExportResult

    /// Отменяет активный picker или копирование.
    func cancelCurrentExport()
}

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
    /// Экспортирует треки через временную папку и системный picker.
    @discardableResult
    func exportViaTempAndPicker(
        _ tracks: [Track],
        presenter: UIViewController
    ) async throws -> ExportManager.ExportResult
}

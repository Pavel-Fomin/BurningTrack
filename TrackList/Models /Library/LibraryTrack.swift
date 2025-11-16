//
//  LibraryTrack.swift
//  TrackList
//
//  Модель трека Фонотеки
//
//  Created by Pavel Fomin on 05.07.2025.
//

import Foundation
import UIKit


struct LibraryTrack: Identifiable, TrackDisplayable {

    // MARK: - Identity
    let id: UUID              // trackId в TrackRegistry

    // MARK: - Файл
    let fileURL: URL          // фактический URL

    // MARK: - Metadata
    let title: String?
    let artist: String?
    let duration: Double
    let addedDate: Date

    // MARK: - TrackDisplayable

    /// Имя файла
    var fileName: String {
        fileURL.deletingPathExtension().lastPathComponent
    }

    /// UI флаг — доступность файла
    var isAvailable: Bool {
        FileManager.default.fileExists(atPath: fileURL.path)
    }

    var artwork: UIImage? { nil }

    /// Универсальный URL для плеера
    var url: URL {
        fileURL
    }
}

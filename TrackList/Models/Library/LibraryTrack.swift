//
//  LibraryTrack.swift
//  TrackList
//
//  Модель трека Фонотеки
//
//  Created by Pavel Fomin on 05.07.2025.
//
import Foundation
struct LibraryTrack: Identifiable, TrackDisplayable {
    // MARK: - Идентичность
    /// Канонический идентификатор локального трека: первичный ключ строки tracks в SQLite.
    let id: UUID
    /// Псевдоним канонического идентификатора для общих моделей трека.
    var trackId: UUID { id }
    // MARK: - Файл
    let fileURL: URL
    // MARK: - Метаданные
    let title: String?
    let artist: String?
    let duration: Double
    let addedDate: Date
    let isAvailable: Bool

    init(
        id: UUID,
        fileURL: URL,
        title: String?,
        artist: String?,
        duration: Double,
        addedDate: Date,
        isAvailable: Bool = true
    ) {
        self.id = id
        self.fileURL = fileURL
        self.title = title
        self.artist = artist
        self.duration = duration
        self.addedDate = addedDate
        self.isAvailable = isAvailable
    }

    // MARK: - TrackDisplayable
    /// Имя файла
    var fileName: String {
        fileURL.lastPathComponent
    }
    /// Универсальный URL для плеера
    var url: URL {
        fileURL
    }
}

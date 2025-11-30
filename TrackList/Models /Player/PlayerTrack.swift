//
//  PlayerTrack.swift
//  TrackList
//
//  Модель трека для Плеера
//  Runtime + Codable
//  Сохраняется в player.json
//  URL определяется через TrackRegistry по trackId
//
//  Created by Pavel Fomin on 07.08.2025.
//

import Foundation
import UIKit

struct PlayerTrack: Identifiable, TrackDisplayable, Codable, Equatable {

    // MARK: - Identity
    let id: UUID               // trackId из TrackRegistry

    // MARK: - Metadata
    let title: String?
    let artist: String?
    let duration: Double
    let fileName: String

    // MARK: - Availability
    let isAvailable: Bool

    // MARK: - Artwork (runtime only — не кодируем)
    var artwork: UIImage? { nil }

    // MARK: - Init
    init(
        id: UUID,
        title: String?,
        artist: String?,
        duration: Double,
        fileName: String,
        isAvailable: Bool
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.fileName = fileName
        self.isAvailable = isAvailable
    }
}

// MARK: - Init from LibraryTrack

extension PlayerTrack {
    /// Синхронная обёртка
    static func make(from track: LibraryTrack) -> PlayerTrack {
        PlayerTrack(
            id: track.id,
            title: track.title,
            artist: track.artist,
            duration: track.duration,
            fileName: track.fileURL.lastPathComponent,
            isAvailable: true
        )
    }
}
// MARK: - Конвертация в Track (треки треклиста)

extension PlayerTrack {
    func asTrack() -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            duration: duration,
            fileName: fileName,
            isAvailable: isAvailable
        )
    }
}

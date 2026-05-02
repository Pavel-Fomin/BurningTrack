//
//  TrackListTrack.swift
//  TrackList
//
//  Модель трека для треклиста
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation
import UIKit

// MARK: - Основная модель трека

struct Track: Identifiable, TrackDisplayable, Codable {
    
    // MARK: - Identity
    let id: UUID
    
    // MARK: - Metadata
    let title: String?
    let artist: String?
    let duration: Double
    let fileName: String
    
    // MARK: - Availability
    let isAvailable: Bool
    
    // MARK: - Artwork
    var artwork: UIImage? { nil }
}

// MARK: - Equatable
extension Track: Equatable {
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

extension Track {
    /// Создаёт трек треклиста из трека фонотеки.
    /// Используется при добавлении треков из прикреплённых папок в новый или существующий треклист.
    init(libraryTrack: LibraryTrack) {
        self.init(
            id: libraryTrack.id,
            title: libraryTrack.title,
            artist: libraryTrack.artist,
            duration: libraryTrack.duration,
            fileName: libraryTrack.fileName,
            isAvailable: libraryTrack.isAvailable
        )
    }
}

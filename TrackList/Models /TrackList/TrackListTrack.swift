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

    // MARK: - TrackDisplayable

    /// Резолвим URL через TrackRegistry (всегда должен быть resolved)
    var resolvedURL: URL {
        TrackRegistry.shared.resolvedURLSync(for: id)
        ?? URL(fileURLWithPath: "/dev/null")
    }

    /// Удобный alias (не обязателен, но полезен)
    var url: URL { resolvedURL }
}


// MARK: - Availability refresh

extension Track {

    func refreshAvailability() -> Track {
        let url = resolvedURL
        let accessible = url.startAccessingSecurityScopedResource()
        defer { if accessible { url.stopAccessingSecurityScopedResource() } }

        let exists = accessible && FileManager.default.fileExists(atPath: url.path)

        return Track(
            id: id,
            title: title,
            artist: artist,
            duration: duration,
            fileName: fileName,
            isAvailable: exists
        )
    }
}


// MARK: - Equatable

extension Track: Equatable {
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

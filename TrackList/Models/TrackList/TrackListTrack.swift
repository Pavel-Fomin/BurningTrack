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
    let listItemId: UUID
    let trackId: UUID
    
    var id: UUID { listItemId }
    
    // MARK: - Metadata
    let title: String?
    let artist: String?
    let duration: Double
    let fileName: String
    
    // MARK: - Availability
    let isAvailable: Bool
    
    // MARK: - Artwork
    var artwork: UIImage? { nil }
    // MARK: - Init
    init(
        listItemId: UUID = UUID(),
        trackId: UUID,
        title: String?,
        artist: String?,
        duration: Double,
        fileName: String,
        isAvailable: Bool
    ) {
        self.listItemId = listItemId
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.duration = duration
        self.fileName = fileName
        self.isAvailable = isAvailable
    }
}
// MARK: - Codable
extension Track {
    private enum CodingKeys: String, CodingKey {
        case listItemId
        case trackId
        case id
        case title
        case artist
        case duration
        case fileName
        case isAvailable
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTrackId = try container.decodeIfPresent(UUID.self, forKey: .trackId)
            ?? container.decode(UUID.self, forKey: .id)
        self.listItemId = try container.decodeIfPresent(UUID.self, forKey: .listItemId) ?? UUID()
        self.trackId = decodedTrackId
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.artist = try container.decodeIfPresent(String.self, forKey: .artist)
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.isAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable) ?? true
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(listItemId, forKey: .listItemId)
        try container.encode(trackId, forKey: .trackId)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encode(duration, forKey: .duration)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(isAvailable, forKey: .isAvailable)
    }
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
            trackId: libraryTrack.trackId,
            title: libraryTrack.title,
            artist: libraryTrack.artist,
            duration: libraryTrack.duration,
            fileName: libraryTrack.fileName,
            isAvailable: libraryTrack.isAvailable
        )
    }
}

//
//  PlayerTrack.swift
//  TrackList
//
//  Модель трека для Плеера
//  Runtime display-модель.
//  Codable сохранён для совместимости, но источником runtime-метаданных является TrackRuntimeSnapshot.
//  Runtime-модель строки плеера.
//  В player.json сохраняются queueItemId и trackId.
//  URL определяется через TrackRegistry по trackId
//
//  Created by Pavel Fomin on 07.08.2025.
//
import Foundation
import UIKit
struct PlayerTrack: Identifiable, TrackDisplayable, Codable, Equatable {
    // MARK: - Identity
    let queueItemId: UUID     // id конкретного вхождения трека в очереди плеера
    let trackId: UUID         // trackId из TrackRegistry
    var id: UUID { queueItemId }
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
        queueItemId: UUID = UUID(),
        trackId: UUID,
        title: String?,
        artist: String?,
        duration: Double,
        fileName: String,
        isAvailable: Bool
    ) {
        self.queueItemId = queueItemId
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.duration = duration
        self.fileName = fileName
        self.isAvailable = isAvailable
    }
}
// MARK: - Codable
extension PlayerTrack {
    private enum CodingKeys: String, CodingKey {
        case queueItemId
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
        self.queueItemId = try container.decodeIfPresent(UUID.self, forKey: .queueItemId) ?? UUID()
        self.trackId = decodedTrackId
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.artist = try container.decodeIfPresent(String.self, forKey: .artist)
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.isAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable) ?? true
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(queueItemId, forKey: .queueItemId)
        try container.encode(trackId, forKey: .trackId)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encode(duration, forKey: .duration)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(isAvailable, forKey: .isAvailable)
    }
}
// MARK: - Init from LibraryTrack
extension PlayerTrack {
    /// Синхронная обёртка
    static func make(from track: LibraryTrack) -> PlayerTrack {
        PlayerTrack(
            trackId: track.trackId,
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
            trackId: trackId,
            title: title,
            artist: artist,
            duration: duration,
            fileName: fileName,
            isAvailable: isAvailable
        )
    }
}

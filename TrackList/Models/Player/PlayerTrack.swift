//
//  PlayerTrack.swift
//  TrackList
//
//  Модель трека для Плеера
//  Runtime display-модель.
//  Codable сохранён для совместимости, но источником runtime-метаданных является TrackRuntimeSnapshot.
//  Runtime-модель строки плеера.
//  Для library-треков в player.json сохраняются queueItemId и trackId.
//  URL library-трека определяется через TrackRegistry по trackId.
//  Для iTunes-трека дополнительно сохраняются текущие метаданные и artworkData.
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
    let album: String?
    let artworkData: Data?
    let duration: Double
    let fileName: String
    /// Источник нужен, чтобы iTunes-трек не попадал в BookmarkResolver.
    let source: TrackSource
    /// URL iTunes-трека из MediaPlayer; для файлов фонотеки остаётся nil.
    let assetURL: URL?
    // MARK: - Availability
    let isAvailable: Bool
    // MARK: - Artwork
    var artwork: UIImage? {
        guard source == .purchasedITunes else { return nil }

        return ArtworkProvider.shared.image(
            trackId: trackId,
            artworkData: artworkData,
            purpose: .trackList
        )
    }
    // MARK: - Init
    init(
        queueItemId: UUID = UUID(),
        trackId: UUID,
        title: String?,
        artist: String?,
        album: String? = nil,
        artworkData: Data? = nil,
        duration: Double,
        fileName: String,
        isAvailable: Bool,
        source: TrackSource = .library,
        assetURL: URL? = nil
    ) {
        self.queueItemId = queueItemId
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkData = artworkData
        self.duration = duration
        self.fileName = fileName
        self.source = source
        self.assetURL = assetURL
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
        case album
        case artworkData
        case duration
        case fileName
        case source
        case assetURL
        case isAvailable
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTrackId = try container.decodeIfPresent(UUID.self, forKey: .trackId)
            ?? container.decode(UUID.self, forKey: .id)
        let decodedSource = try container.decodeIfPresent(TrackSource.self, forKey: .source) ?? .library
        let decodedAssetURL = try container.decodeIfPresent(URL.self, forKey: .assetURL)
        self.queueItemId = try container.decodeIfPresent(UUID.self, forKey: .queueItemId) ?? UUID()
        self.trackId = decodedTrackId
        self.title = try container.decodeIfPresent(String.self, forKey: .title)
        self.artist = try container.decodeIfPresent(String.self, forKey: .artist)
        self.album = try container.decodeIfPresent(String.self, forKey: .album)
        // Обложку сохраняем только для iTunes-треков, потому что для них нет файловой цепочки метаданных приложения.
        self.artworkData = decodedSource == .purchasedITunes
            ? try container.decodeIfPresent(Data.self, forKey: .artworkData)
            : nil
        self.duration = try container.decodeIfPresent(Double.self, forKey: .duration) ?? 0
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.source = decodedSource
        self.assetURL = decodedAssetURL
        let decodedIsAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable) ?? true
        self.isAvailable = decodedSource == .purchasedITunes
            ? decodedAssetURL != nil && decodedIsAvailable
            : decodedIsAvailable
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(queueItemId, forKey: .queueItemId)
        try container.encode(trackId, forKey: .trackId)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        if source == .purchasedITunes {
            // Для iTunes-трека это единственный источник обложки после восстановления очереди плеера.
            try container.encodeIfPresent(artworkData, forKey: .artworkData)
        }
        try container.encode(duration, forKey: .duration)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(assetURL, forKey: .assetURL)
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
// MARK: - Init from PurchasedITunesPlayableTrack
extension PlayerTrack {
    /// Создаёт элемент очереди из iTunes-трека без копирования файла.
    static func make(from track: PurchasedITunesPlayableTrack) -> PlayerTrack {
        PlayerTrack(
            trackId: track.trackId,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artworkData: track.artworkData,
            duration: track.duration,
            fileName: track.fileName,
            isAvailable: track.isAvailable,
            source: .purchasedITunes,
            assetURL: track.assetURL
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
            album: album,
            artworkData: artworkData,
            duration: duration,
            fileName: fileName,
            isAvailable: isAvailable,
            source: source,
            assetURL: assetURL
        )
    }
}

// MARK: - PurchasedITunesTrackRepresentable
extension PlayerTrack: PurchasedITunesTrackRepresentable {
    var purchasedITunesAssetURL: URL? {
        assetURL
    }
}

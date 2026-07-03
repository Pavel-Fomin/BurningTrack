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
    let album: String?
    let artworkData: Data?
    let duration: Double
    let fileName: String
    /// Источник нужен, чтобы iTunes-трек не смешивался с файловой фонотекой.
    let source: TrackSource
    /// URL iTunes-трека из MediaPlayer; для обычных файлов остаётся nil.
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
        listItemId: UUID = UUID(),
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
        self.listItemId = listItemId
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
extension Track {
    private enum CodingKeys: String, CodingKey {
        case listItemId
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
        self.listItemId = try container.decodeIfPresent(UUID.self, forKey: .listItemId) ?? UUID()
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
        try container.encode(listItemId, forKey: .listItemId)
        try container.encode(trackId, forKey: .trackId)
        try container.encodeIfPresent(title, forKey: .title)
        try container.encodeIfPresent(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        if source == .purchasedITunes {
            // Для iTunes-трека это единственный источник обложки для mini player, Now Playing и sheet "О треке".
            try container.encodeIfPresent(artworkData, forKey: .artworkData)
        }
        try container.encode(duration, forKey: .duration)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(assetURL, forKey: .assetURL)
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

extension Track {
    /// Создаёт строку треклиста из iTunes-трека без копирования файла.
    init(purchasedITunesTrack: PurchasedITunesPlayableTrack) {
        self.init(
            trackId: purchasedITunesTrack.trackId,
            title: purchasedITunesTrack.title,
            artist: purchasedITunesTrack.artist,
            album: purchasedITunesTrack.album,
            artworkData: purchasedITunesTrack.artworkData,
            duration: purchasedITunesTrack.duration,
            fileName: purchasedITunesTrack.fileName,
            isAvailable: purchasedITunesTrack.isAvailable,
            source: .purchasedITunes,
            assetURL: purchasedITunesTrack.assetURL
        )
    }
}

// MARK: - PurchasedITunesTrackRepresentable
extension Track: PurchasedITunesTrackRepresentable {
    var purchasedITunesAssetURL: URL? {
        assetURL
    }
}

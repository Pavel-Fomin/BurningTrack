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
struct Track: Identifiable, TrackDisplayable {
    
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

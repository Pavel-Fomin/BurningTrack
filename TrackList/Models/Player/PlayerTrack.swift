//
//  PlayerTrack.swift
//  TrackList
//
//  Модель трека для Плеера
//  Runtime display-модель.
//  Runtime-модель строки плеера.
//  Для library-треков сохраняются queueItemId и trackId.
//  URL library-трека определяется через TrackRegistry по trackId.
//  Для iTunes-трека дополнительно сохраняются текущие метаданные.
//
//  Created by Pavel Fomin on 07.08.2025.
//
import Foundation
struct PlayerTrack: Identifiable, TrackDisplayable, Equatable {
    // MARK: - Identity
    /// Идентифицирует конкретное вхождение трека в очереди, включая дубликаты.
    let queueItemId: UUID
    /// Идентифицирует сам музыкальный трек в TrackRegistry.
    let trackId: UUID
    /// UI-идентичность элемента очереди; переходы в очереди используют queueItemId.
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

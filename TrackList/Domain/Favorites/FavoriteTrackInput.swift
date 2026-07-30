//
//  FavoriteTrackInput.swift
//  TrackList
//
//  Входная модель трека для системного треклиста «Избранное».
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Снимок данных, достаточный для создания новой строки в системном треклисте «Избранное».
/// Не зависит от UI-протоколов и отделяет логический trackId от нового идентификатора строки списка.
struct FavoriteTrackInput: Equatable {

    /// Логический идентификатор исходного трека: tracks.id для локального трека или устойчивый ID iTunes-адаптера.
    let trackId: UUID
    let title: String?
    let artist: String?
    let album: String?
    let artworkData: Data?
    let duration: Double
    let fileName: String
    let isAvailable: Bool
    let source: TrackSource
    let assetURL: URL?

    init(
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
        self.trackId = trackId
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkData = artworkData
        self.duration = duration
        self.fileName = fileName
        self.isAvailable = isAvailable
        self.source = source
        self.assetURL = assetURL
    }

    /// Создаёт входную модель из существующей строки треклиста, сохраняя её логическую идентичность и snapshot.
    init(track: Track) {
        self.init(
            trackId: track.trackId,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artworkData: track.artworkData,
            duration: track.duration,
            fileName: track.fileName,
            isAvailable: track.isAvailable,
            source: track.source,
            assetURL: track.assetURL
        )
    }

    /// Создаёт входную модель локального трека с его каноническим идентификатором строки tracks.
    init(libraryTrack: LibraryTrack) {
        self.init(
            trackId: libraryTrack.id,
            title: libraryTrack.title,
            artist: libraryTrack.artist,
            duration: libraryTrack.duration,
            fileName: libraryTrack.fileName,
            isAvailable: libraryTrack.isAvailable,
            source: .library
        )
    }

    /// Создаёт входную модель iTunes-трека с устойчивым внешним идентификатором существующего адаптера.
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

    /// Создаёт входную модель из текущей display-модели плеера, сохраняя канонический trackId и доступный snapshot.
    init(playerTrack: any TrackDisplayable) {
        let sourceTrack = playerTrack as? any PurchasedITunesTrackRepresentable

        self.init(
            trackId: playerTrack.trackId,
            title: playerTrack.title,
            artist: playerTrack.artist,
            album: sourceTrack?.album,
            artworkData: sourceTrack?.artworkData,
            duration: playerTrack.duration,
            fileName: playerTrack.fileName,
            isAvailable: playerTrack.isAvailable,
            source: sourceTrack?.source ?? .library,
            assetURL: sourceTrack?.purchasedITunesAssetURL
        )
    }

    /// Создаёт новую строку треклиста, намеренно не перенося listItemId из исходной модели.
    func makeTrackListTrack() -> Track {
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

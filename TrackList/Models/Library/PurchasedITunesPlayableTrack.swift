//
//  PurchasedITunesPlayableTrack.swift
//  TrackList
//
//  Лёгкий адаптер трека iTunes под общий playback-протокол приложения.
//  Не добавляет трек в фонотеку и не смешивает его с LibraryTrack.
//
//  Created by Pavel Fomin on 02.07.2026.
//

import Foundation

struct PurchasedITunesPlayableTrack: Identifiable, TrackDisplayable, Hashable {
    // MARK: - Идентификация

    let id: UUID
    let trackId: UUID

    // MARK: - Данные медиатеки

    let title: String?
    let artist: String?
    let album: String?
    let artworkData: Data?
    let duration: Double
    let fileName: String
    let assetURL: URL
    let isAvailable: Bool

    // MARK: - Инициализация

    init(
        track: PurchasedITunesTrack
    ) {
        // Создаём стабильный UUID из persistentID системной медиатеки.
        let stableId = UUID.v5(from: "purchased-itunes:\(track.id)")

        self.id = stableId
        self.trackId = stableId
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.artworkData = track.artworkData
        self.duration = track.duration
        // Для мини-плеера используем человекочитаемое название вместо технического assetURL.
        self.fileName = track.title
        self.assetURL = track.assetURL
        self.isAvailable = true
    }

    /// Собирает iTunes playback-адаптер из модели очереди или треклиста.
    init?(
        purchasedITunesSource track: any TrackDisplayable & PurchasedITunesTrackRepresentable
    ) {
        guard track.source == .purchasedITunes,
              let assetURL = track.purchasedITunesAssetURL
        else {
            return nil
        }

        self.id = track.id
        self.trackId = track.trackId
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.artworkData = track.artworkData
        self.duration = track.duration
        self.fileName = track.fileName
        self.assetURL = assetURL
        self.isAvailable = track.isAvailable
    }

    /// Сравниваем iTunes-адаптеры только по стабильному trackId, не по runtime-обложке.
    static func == (
        lhs: PurchasedITunesPlayableTrack,
        rhs: PurchasedITunesPlayableTrack
    ) -> Bool {
        lhs.trackId == rhs.trackId
    }

    /// Хеш строится только из стабильного trackId, который получен из persistentID.
    func hash(
        into hasher: inout Hasher
    ) {
        hasher.combine(trackId)
    }
}

// MARK: - PurchasedITunesTrackRepresentable
extension PurchasedITunesPlayableTrack: PurchasedITunesTrackRepresentable {
    /// iTunes-адаптер всегда представляет runtime-источник MediaPlayer.
    var source: TrackSource {
        .purchasedITunes
    }

    /// Возвращает готовый assetURL из MediaPlayer через общий протокол iTunes-источников.
    var purchasedITunesAssetURL: URL? {
        assetURL
    }
}

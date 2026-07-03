//
//  TrackSource.swift
//  TrackList
//
//  Источник трека внутри пользовательских списков приложения.
//
//  Created by Codex on 02.07.2026.
//

import Foundation

/// Показывает, откуда пришёл трек, не смешивая модели фонотеки и iTunes.
enum TrackSource: String, Codable {
    /// Обычный файловый трек из прикреплённой фонотеки.
    case library
    /// Купленный iTunes-трек из системной медиатеки.
    case purchasedITunes
}

/// Runtime-данные iTunes-трека, которые нельзя резолвить через BookmarkResolver.
protocol PurchasedITunesTrackRepresentable {
    /// Источник трека для выбора playback-pipeline.
    var source: TrackSource { get }
    /// Альбом из системной медиатеки, если он известен.
    var album: String? { get }
    /// Runtime-данные обложки; для iTunes-источника сохраняются в пользовательских списках.
    var artworkData: Data? { get }
    /// Готовый assetURL из MediaPlayer.
    var purchasedITunesAssetURL: URL? { get }
}

extension TrackDisplayable {
    /// Признак iTunes-трека с готовым runtime assetURL.
    var isPurchasedITunesRuntimeTrack: Bool {
        guard let track = self as? (any PurchasedITunesTrackRepresentable) else {
            return false
        }

        return track.source == .purchasedITunes &&
        track.purchasedITunesAssetURL != nil
    }

    /// Собирает playback-адаптер iTunes из модели очереди или треклиста.
    func asPurchasedITunesPlayableTrack() -> PurchasedITunesPlayableTrack? {
        guard let sourceTrack = self as? (any TrackDisplayable & PurchasedITunesTrackRepresentable) else {
            return nil
        }

        return PurchasedITunesPlayableTrack(
            purchasedITunesSource: sourceTrack
        )
    }
}

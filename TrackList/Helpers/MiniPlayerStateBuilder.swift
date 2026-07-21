//
//  MiniPlayerStateBuilder.swift
//  TrackList
//
//  Builder состояния мини-плеера.
//
//  Роль:
//  - собирает MiniPlayerStaticState из трека и каноничного runtime snapshot
//  - формирует title / artist
//  - создаёт artwork UIImage для мини-плеера
//
//  ВАЖНО:
//  - вся тяжёлая логика сборки обложки должна быть только здесь
//  - MiniPlayerView не должен знать про metadata cache и ArtworkProvider
//
//  Created by Pavel Fomin on 08.02.2026.
//

import Foundation
import UIKit

final class MiniPlayerStateBuilder {

    @MainActor
    static func buildStaticState(
        track: any TrackDisplayable,
        snapshot: TrackRuntimeSnapshot?
    ) -> MiniPlayerStaticState {

        if let purchasedTrack = track as? (any TrackDisplayable & PurchasedITunesTrackRepresentable),
           purchasedTrack.isPurchasedITunesRuntimeTrack {
            return buildPurchasedITunesStaticState(
                track: purchasedTrack
            )
        }

        let shouldShowTags = AppSettingsManager.shared.settings.visible.metadata.isTagReadingEnabled

        // Название берём из snapshot, если оно есть.
        // Если в тегах пусто — показываем имя файла.
        let title: String = {
            if !shouldShowTags { return track.fileName }

            if snapshot?.title?.isEmpty == false {
                return snapshot?.title ?? ""
            }

            return track.fileName
        }()

        // Исполнителя берём из snapshot, если он есть.
        // Если в тегах пусто — передаём отсутствие metadata в presentation-слой.
        let artist: String? = {
            if !shouldShowTags { return nil }

            if snapshot?.artist?.isEmpty == false {
                return snapshot?.artist
            }

            return nil
        }()

        // Обложку строим из artworkData внутри snapshot.
        let artwork: UIImage? = {
            guard shouldShowTags else { return nil }
            guard let data = snapshot?.artworkData else { return nil }

            return ArtworkProvider.shared.image(
                trackId: track.trackId,
                artworkData: data,
                purpose: .miniPlayer
            )
        }()

        return MiniPlayerStaticState(
            trackId: track.trackId,
            title: title,
            artist: artist,
            artwork: artwork
        )
    }

    /// Собирает состояние мини-плеера для iTunes-трека из runtime-данных MediaPlayer.
    private static func buildPurchasedITunesStaticState(
        track: any TrackDisplayable & PurchasedITunesTrackRepresentable
    ) -> MiniPlayerStaticState {
        let title: String = {
            if track.title?.isEmpty == false {
                return track.title ?? ""
            }

            return track.fileName
        }()

        let artist: String? = {
            if track.artist?.isEmpty == false {
                return track.artist
            }

            return nil
        }()

        // Для iTunes-трека не читаем файл и не используем TrackMetadataCacheManager.
        let artwork = ArtworkProvider.shared.image(
            trackId: track.trackId,
            artworkData: track.artworkData,
            purpose: .miniPlayer
        )

        return MiniPlayerStaticState(
            trackId: track.trackId,
            title: title,
            artist: artist,
            artwork: artwork
        )
    }
}

//
//  MiniPlayerStateBuilder.swift
//  TrackList
//
//  Builder состояния мини-плеера.
//
//  Роль:
//  - собирает MiniPlayerStaticState из трека и каноничного runtime snapshot
//  - формирует title / artist
//  - создаёт лёгкий ArtworkRequest для мини-плеера
//
//  ВАЖНО:
//  - тяжёлая подготовка выполняется общей подсистемой после подписки View
//  - MiniPlayerView не должен знать про metadata cache и ImageIO
//
//  Created by Pavel Fomin on 08.02.2026.
//

import Foundation

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

        // Запрос обложки строим из artworkData внутри snapshot без декодирования.
        let artworkRequest: ArtworkRequest? = {
            guard shouldShowTags else { return nil }
            return ArtworkRequest(
                trackId: track.trackId,
                snapshot: snapshot,
                purpose: .miniPlayer
            )
        }()

        return MiniPlayerStaticState(
            trackId: track.trackId,
            title: title,
            artist: artist,
            artworkRequest: artworkRequest
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
        let artworkRequest = ArtworkRequest(
            trackId: track.trackId,
            artworkData: track.artworkData,
            purpose: .miniPlayer,
            sourceIdentifier: .mediaLibrary(trackId: track.trackId)
        )

        return MiniPlayerStaticState(
            trackId: track.trackId,
            title: title,
            artist: artist,
            artworkRequest: artworkRequest
        )
    }
}

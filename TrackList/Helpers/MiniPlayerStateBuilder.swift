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

    static func buildStaticState(
        track: any TrackDisplayable,
        snapshot: TrackRuntimeSnapshot?
    ) -> MiniPlayerStaticState {

        // Название берём из snapshot, если оно есть.
        // Если в тегах пусто — показываем имя файла.
        let title = (snapshot?.title?.isEmpty == false)
        ? (snapshot?.title ?? "")
        : track.fileName

        // Исполнителя берём из snapshot, если он есть.
        // Если в тегах пусто — показываем fallback.
        let artist = (snapshot?.artist?.isEmpty == false)
        ? (snapshot?.artist ?? "")
        : "Неизвестный артист"

        // Обложку строим из artworkData внутри snapshot.
        let artwork: UIImage? = {
            guard let data = snapshot?.artworkData else { return nil }

            return ArtworkProvider.shared.image(
                trackId: track.id,
                artworkData: data,
                purpose: .miniPlayer
            )
        }()

        return MiniPlayerStaticState(
            trackId: track.id,
            title: title,
            artist: artist,
            artwork: artwork
        )
    }
}

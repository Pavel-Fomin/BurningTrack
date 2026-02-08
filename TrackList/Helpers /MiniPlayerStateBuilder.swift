//
//  MiniPlayerStateBuilder.swift
//  TrackList
//
//  Builder состояния мини-плеера.
//
//  Роль:
//  - собирает MiniPlayerStaticState из трека и метаданных
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
        metadata: TrackMetadataCacheManager.CachedMetadata?
    ) -> MiniPlayerStaticState {

        let title = (metadata?.title?.isEmpty == false)
        ? (metadata?.title ?? "")
        : track.fileName

        let artist = (metadata?.artist?.isEmpty == false)
        ? (metadata?.artist ?? "")
        : "Неизвестный артист"

        let artwork: UIImage? = {
            guard let data = metadata?.artworkData else { return nil }

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

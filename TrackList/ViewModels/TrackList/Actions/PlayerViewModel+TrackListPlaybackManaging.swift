//
//  PlayerViewModel+TrackListPlaybackManaging.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

extension PlayerViewModel: TrackListPlaybackManaging {
    /// Запускает трек из detail-flow треклиста через общий playback API.
    func play(
        track: Track,
        context: [Track]
    ) {
        let playbackTrack: any TrackDisplayable = track
        let playbackContext = context.map { track in
            track as any TrackDisplayable
        }

        play(
            track: playbackTrack,
            context: playbackContext
        )
    }
}

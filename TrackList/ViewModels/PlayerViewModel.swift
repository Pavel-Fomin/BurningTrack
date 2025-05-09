//
//  PlayerViewModel.swift
//  TrackList
//
//  Управление воспроизведением — play/pause/next/seek
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import AVFoundation

final class PlayerViewModel: ObservableObject {
    @Published var currentTrack: Track?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var trackDuration: TimeInterval = 0.0

    let playerManager = PlayerManager()

    func play(track: Track) {
        print("🧠 PlayerViewModel: play(track:) вызван с", track.fileName)

        
        // MARK: - Проверяем — если трек тот же самый, просто продолжаем
        if currentTrack?.url == track.url {
            playerManager.playCurrent()
        } else {
            playerManager.stopAccessingCurrentTrack()
            playerManager.play(track: track)
            currentTrack = track
        }
        isPlaying = true
        trackDuration = track.duration
    }

    func togglePlayPause() {
        if isPlaying {
            playerManager.pause()
        } else {
            guard let track = currentTrack else { return }

            // Если воспроизводим тот же трек — просто продолжаем
            playerManager.playCurrent()
        }
        isPlaying.toggle()
    }

    func seek(to time: TimeInterval) {
        playerManager.seek(to: time)
        self.currentTime = time
    }
}

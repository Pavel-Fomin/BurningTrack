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
    let trackListViewModel: TrackListViewModel
    init(trackListViewModel: TrackListViewModel) {
        self.trackListViewModel = trackListViewModel
        NotificationCenter.default.addObserver(
            forName: .trackDurationUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let duration = notification.userInfo?["duration"] as? TimeInterval {
                self?.trackDuration = duration
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .trackDidFinish,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.playNextTrack() }
        }

        playerManager.setupRemoteCommandCenter(
            onPlay: { [weak self] in
                DispatchQueue.main.async {
                    self?.togglePlayPause()
                }
            },
            onPause: { [weak self] in
                DispatchQueue.main.async {
                    self?.togglePlayPause()
                }
            },
            onNext: { [weak self] in
                DispatchQueue.main.async {
                    self?.playNextTrack()
                }
            },
            onPrevious: { [weak self] in
                DispatchQueue.main.async {
                    self?.playPreviousTrack()
                }
            }
        )
    }

    func play(track: Track) {
        print("🧠 PlayerViewModel: play(track:) вызван с", track.fileName)

        if currentTrack?.url == track.url {
            playerManager.playCurrent()
        } else {
            playerManager.stopAccessingCurrentTrack()
            playerManager.play(track: track)
            currentTrack = track

            playerManager.updateNowPlayingInfo(
                track: track,
                currentTime: 0,
                duration: trackDuration
            )
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.playerManager.updateNowPlayingInfo(
                    track: track,
                    currentTime: 0,
                    duration: self.trackDuration
                )
            }

            playerManager.observeProgress { [weak self] time in
                self?.currentTime = time
                if let self = self {
                    self.playerManager.updatePlaybackTimeOnly(
                        currentTime: time,
                        isPlaying: self.isPlaying
                    )
                    
                }
            }
        }

        isPlaying = true
    }

    func togglePlayPause() { /// Плей/Пауза
        if isPlaying {
            playerManager.pause()
        } else {
            guard currentTrack != nil else { return }
            playerManager.playCurrent()
        }
        isPlaying.toggle()
    }

    func seek(to time: TimeInterval) { /// Перемотка
        playerManager.seek(to: time)
        self.currentTime = time
    }
    
    @MainActor
    func playNextTrack() {
        guard let current = currentTrack else { return }
        let tracks = trackListViewModel.tracks
        guard let index = tracks.firstIndex(of: current),
              index + 1 < tracks.count else {
            print("⏭ Следующего трека нет")
            return
        }

        let nextTrack = tracks[index + 1]
        play(track: nextTrack)
    }
    
    @MainActor
    func playPreviousTrack() {
        guard let current = currentTrack else { return }
        let tracks = trackListViewModel.tracks
        guard let index = tracks.firstIndex(of: current),
              index - 1 >= 0 else {
            print("⏮ Предыдущего трека нет")
            return
        }

        let previousTrack = tracks[index - 1]
        play(track: previousTrack)
    }

    deinit {/// Освобождаем observer при удалении ViewModel
        playerManager.removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }
}

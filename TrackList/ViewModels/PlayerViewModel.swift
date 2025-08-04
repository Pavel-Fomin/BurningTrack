//
//  PlayerViewModel.swift
//  TrackList
//
//  ViewModel для управления воспроизведением треков:
//  - старт/пауза, перемотка, переход к следующему/предыдущему,
//  - наблюдение за прогрессом,
//  - взаимодействие с Control Center и NowPlayingInfo
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import AVFoundation

@MainActor
final class PlayerViewModel: ObservableObject {
    
// MARK: - Состояние воспроизведения
    
    @Published var currentTrackDisplayable: (any TrackDisplayable)? /// Текущий воспроизводимый трек
    @Published var isPlaying: Bool = false                          /// Воспроизводится ли в данный момент
    @Published var currentTime: TimeInterval = 0.0                  /// Текущее время воспроизведения
    @Published var trackDuration: TimeInterval = 0.0                /// Длительность трека

    let playerManager = PlayerManager()                             /// Низкоуровневый контроллер плеера
    
    var libraryTracksContext: [LibraryTrack] = []
    
    private var trackListContext: [Track] = []

    
    
// MARK: - Инициализация и подписка на события
       
    init() {
        NotificationCenter.default.addObserver(
            forName: .trackDurationUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let duration = notification.userInfo?["duration"] as? TimeInterval {
                Task { @MainActor in
                    self?.trackDuration = duration
                }
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

       
// MARK: - Воспроизведение трека
       
    func play(track: any TrackDisplayable, context: [any TrackDisplayable] = []) {

        if let current = currentTrackDisplayable,
           current.fileName == track.fileName {
            playerManager.playCurrent()
        } else {
            playerManager.stopAccessingCurrentTrack()
            currentTrackDisplayable = track

            if track is LibraryTrack {
                self.libraryTracksContext = context.compactMap { $0 as? LibraryTrack }
                self.trackListContext = []
            } else if track is Track {
                self.trackListContext = context.compactMap { $0 as? Track }
                self.libraryTracksContext = []
            }

            playerManager.play(track: track)

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

        isPlaying = true
    }

       
// MARK: - Управление воспроизведением
       
       func togglePlayPause() {
           if isPlaying {
               playerManager.pause()
           } else {
               guard currentTrackDisplayable != nil else { return }
               playerManager.playCurrent()
           }
           isPlaying.toggle()
       }
       
       func seek(to time: TimeInterval) {
           playerManager.seek(to: time)
           self.currentTime = time
       }
       
       
// MARK: - Переход между треками

    @MainActor
    
    // Следующий трек
    func playNextTrack() {
        guard let current = currentTrackDisplayable else { return }

        if let libTrack = current as? LibraryTrack {
            guard let index = libraryTracksContext.firstIndex(where: { $0.fileName == libTrack.fileName }) else {

                return
            }

            let nextIndex = index + 1
            if nextIndex < libraryTracksContext.count {
                play(track: libraryTracksContext[nextIndex], context: libraryTracksContext)
            } else {
                
            }

        } else if let track = current as? Track {
            guard let index = trackListContext.firstIndex(of: track),
                  index + 1 < trackListContext.count else {
                
                return
            }

            play(track: trackListContext[index + 1], context: trackListContext)
        }
    }
     
    
    @MainActor
    
    // Предыдущий трек
    func playPreviousTrack() {
        guard let current = currentTrackDisplayable else { return }

        if let libTrack = current as? LibraryTrack {
            guard let index = libraryTracksContext.firstIndex(where: { $0.fileName == libTrack.fileName }) else {
                
                return
            }

            let prevIndex = index - 1
            if prevIndex >= 0 {
                play(track: libraryTracksContext[prevIndex], context: libraryTracksContext)
            } else {
                
            }

        } else if let track = current as? Track {
            guard let index = trackListContext.firstIndex(of: track),
                  index - 1 >= 0 else {
                
                return
            }

            play(track: trackListContext[index - 1], context: trackListContext)
        }
    }
       
    
// MARK: - Очистка ресурсов
       
       deinit {
           playerManager.removeTimeObserver()
           NotificationCenter.default.removeObserver(self)
       }
   }

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

final class PlayerViewModel: ObservableObject {
    // MARK: - Состояние воспроизведения
    
    @Published var currentTrack: Track?               /// Текущий воспроизводимый трек
    @Published var isPlaying: Bool = false            /// Воспроизводится ли в данный момент
    @Published var currentTime: TimeInterval = 0.0    /// Текущее время воспроизведения
    @Published var trackDuration: TimeInterval = 0.0  /// Длительность трека

    let playerManager = PlayerManager()               /// Низкоуровневый контроллер плеера
    let trackListViewModel: TrackListViewModel        /// ViewModel со списком треков
    
    // MARK: - Инициализация и подписка на события
    
    init(trackListViewModel: TrackListViewModel) {
        self.trackListViewModel = trackListViewModel
        
        // Обновление длительности трека
        NotificationCenter.default.addObserver(
            forName: .trackDurationUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let duration = notification.userInfo?["duration"] as? TimeInterval {
                self?.trackDuration = duration
            }
        }
        
        // Переход к следующему треку после окончания
        NotificationCenter.default.addObserver(
            forName: .trackDidFinish,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.playNextTrack() }
        }

        // Настройка кнопок в Control Center
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
    
    /// Запускает воспроизведение выбранного трека
    func play(track: Track) {
        print("🧠 PlayerViewModel: play(track:) вызван с", track.fileName)
        
        // Если трек уже воспроизводится — продолжаем
        if currentTrack?.url == track.url {
            playerManager.playCurrent()
        } else {
            playerManager.stopAccessingCurrentTrack()
            playerManager.play(track: track)
            currentTrack = track
            
            // Обновление информации для Control Center
            playerManager.updateNowPlayingInfo(
                track: track,
                currentTime: 0,
                duration: trackDuration
            )
            
            // Повторное обновление с задержкой (на случай запоздалой длительности)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.playerManager.updateNowPlayingInfo(
                    track: track,
                    currentTime: 0,
                    duration: self.trackDuration
                )
            }
            
            // Подписка на прогресс воспроизведения
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

    // MARK: - Управление воспроизведением
    
    /// Переключает воспроизведение/паузу
    func togglePlayPause() {
        if isPlaying {
            playerManager.pause()
        } else {
            guard currentTrack != nil else { return }
            playerManager.playCurrent()
        }
        isPlaying.toggle()
    }
    
    /// Перематывает на указанное время
    func seek(to time: TimeInterval) {
        playerManager.seek(to: time)
        self.currentTime = time
    }
    
    // MARK: - Переход между треками

    /// Переход к следующему треку
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
    
    /// Переход к предыдущему треку
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
    
    // MARK: - Очистка ресурсов
    
    /// Удаление подписок при деинициализации
    deinit {
        playerManager.removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }
}

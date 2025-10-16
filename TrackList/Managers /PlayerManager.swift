//
//  PlayerManager.swift
//  TrackList
//
//  Управляет воспроизведением аудиотреков через AVPlayer.
//  Обрабатывает доступ к файлам, прогресс, Now Playing Info и команды из Control Center
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import Combine
import MediaPlayer
@preconcurrency import AVFoundation

/// Контроллер нижнего уровня для управления AVPlayer
final class PlayerManager {
    private let player = AVPlayer()       /// Основной AVPlayer
    private var timeObserverToken: Any?   /// Токен наблюдения за прогрессом
    private var currentAccessedURL: URL?  /// URL, к которому был открыт доступ (для stopAccessing)
    
    
// MARK: - Инициализация плеера
    
    init() {
        print("🧠 PlayerManager инициализирован")
        
        // Подписка на завершение трека
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    /// Обработка завершения текущего трека — пересылаем событие наверх
    @objc private func trackDidFinishPlaying() {
        NotificationCenter.default.post(name: .trackDidFinish, object: nil)
    }
    
    
// MARK: - Настройка аудиосессии (для воспроизведения в фоне)
    
    /// Включает режим фонового воспроизведения
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            print("🔊 [Init] Аудиосессия активирована")
        } catch {
            
        }
    }
    
    
// MARK: - Универсальный метод воспроизведения трека любого типа
    
    /// Запускает воспроизведение трека — поддерживаются все типы (Imported, Library, Track)
    /// - Parameter track: Трек, соответствующий протоколу TrackDisplayable
    func play(track: any TrackDisplayable) {
        Task {
            do {
                let resolvedURL: URL

                if let libraryTrack = track as? LibraryTrack {
                    print("📀 Это LibraryTrack")
                    guard let resolved = libraryTrack.startAccessingIfNeeded() else { return }
                    resolvedURL = resolved

                } else if let importedTrack = track as? ImportedTrack {
                    print("📥 Это ImportedTrack")
                    guard importedTrack.startAccessingIfNeeded() else { return }
                    resolvedURL = try importedTrack.resolvedURL()

                } else if let savedTrack = track as? Track {
                    print("💾 Это Track")
                    resolvedURL = savedTrack.url

                } else if let playerTrack = track as? PlayerTrack {
                    print("🎧 Это PlayerTrack")
                    resolvedURL = playerTrack.url

                } else {
                    print("❌ Неизвестный тип трека: \(type(of: track))")
                    return
                }

                if resolvedURL == currentAccessedURL {
                    player.play()
                    return
                }
                
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                
                // Закрываем доступ к предыдущему треку
                stopAccessingCurrentTrack()
                currentAccessedURL = resolvedURL
                
                // Создаём AVPlayerItem
                let playerItem = AVPlayerItem(url: resolvedURL)
                
                // Проверка, доступно ли воспроизведение
                _ = try await playerItem.asset.load(.isPlayable)
                
                
                // Устанавливаем item и запускаем плеер
                player.replaceCurrentItem(with: playerItem)
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemFailedToPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { notification in
                    if notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] != nil {
                        
                    } else {
                        
                    }
                }
                player.play()
                
                // Загрузка длительности через разные источники
                let asset = await playerItem.asset
                let duration = try await asset.load(.duration)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                let timeRange = try await audioTracks.first?.load(.timeRange)
                
                let fromTrack = timeRange?.duration.seconds
                let fromAsset = duration.seconds
                let fromPlayer = playerItem.duration.seconds
                
                // Выбираем максимальное валидное значение
                let bestDuration = [fromTrack, fromPlayer, fromAsset]
                    .compactMap { $0 }
                    .filter { $0.isFinite && $0 > 0 }
                    .max() ?? 0
                
                // Уведомляем об обновлении длительности
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .trackDurationUpdated,
                        object: nil,
                        userInfo: ["duration": bestDuration]
                    )
                }
                
                // (Опционально) Повторная проверка длительности через 2 сек
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    Task {
                        do {
                            let duration = try await asset.load(.duration)
                            _ = playerItem.duration.seconds
                            _ = duration.seconds
                            /// Можно сравнить значения
                            
                        } catch {
                            
                        }
                    }
                }
                
            } catch {
                
            }
        }
    }
    
    
// MARK: - Освобождение доступа к текущему треку
    
    /// Закрывает доступ к текущему файлу, если он был открыт через securityScoped
    func stopAccessingCurrentTrack() {
        if let url = currentAccessedURL {
            url.stopAccessingSecurityScopedResource()
            currentAccessedURL = nil
        }
    }
    
    
// MARK: - Управление воспроизведением
    
    // Пауза текущего трека
    func pause() {
        player.pause()
    }
    
    // Перемотка на заданное время
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
    }
    
    // Возобновляет воспроизведение текущего трека (без перезапуска)
    func playCurrent() {
        player.play()
    }
    
    
// MARK: - Подписка на прогресс плеера
    
    /// Подписка на обновление времени воспроизведения
    /// - Parameter update: Замыкание с текущим временем (в секундах)
    func observeProgress(update: @escaping (TimeInterval) -> Void) {
        removeTimeObserver() /// чтобы не дублировать
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            update(time.seconds)
        }
    }
    
    /// Удаляет наблюдатель прогресса (если он есть)
    func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    
// MARK: - Now Playing Info (для Control Center и блокировки экрана)
    
    /// Обновляет отображение информации о треке
    func updateNowPlayingInfo(track: any TrackDisplayable, currentTime: TimeInterval, duration: TimeInterval) {
        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        
        nowPlayingInfo[MPMediaItemPropertyTitle] = track.title ?? track.fileName
        nowPlayingInfo[MPMediaItemPropertyArtist] = track.artist ?? "Неизвестный артист"
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
        
        if let image = track.artwork {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    /// Обновляет только прогресс и статус воспроизведения
    func updatePlaybackTimeOnly(currentTime: TimeInterval, isPlaying: Bool) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    }
    
    
// MARK: - Команды с экрана блокировки
    
    /// Настраивает обработку команд: Play, Pause, Next, Previous, Seek
    func setupRemoteCommandCenter(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
    ) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        /// Play
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }
        /// Pause
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }
        /// Next
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            onNext()
            return .success
        }
        /// Previous
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            onPrevious()
            return .success
        }
        /// Seek
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard
                let self,
                let event = event as? MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }
            
            self.seek(to: event.positionTime)
            return .success
        }
    }
}


// MARK: - Расширение для NotificationCenter
    
    extension Notification.Name {
        
        /// Уведомление о том, что длительность трека обновлена (используется для ViewModel'ов)
        static let trackDurationUpdated = Notification.Name("trackDurationUpdated")
        
        /// Уведомление о завершении воспроизведения трека
        static let trackDidFinish = Notification.Name("trackDidFinish")
    }


    
    
   

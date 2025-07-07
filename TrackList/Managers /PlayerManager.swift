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
@preconcurrency import AVFoundation
import Combine
import MediaPlayer

final class PlayerManager {
    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var currentAccessedURL: URL?
    
    
    // MARK: - Инициализация плеера
    
    init() {
        configureAudioSession()
        
        // Подписка на завершение трека
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
    // Уведомление о завершении трека (для перехода к следующему)
    @objc private func trackDidFinishPlaying() {
        NotificationCenter.default.post(name: .trackDidFinish, object: nil)
    }
    
    // MARK: - Настройка аудиосессии (для воспроизведения в фоне)
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            print("🔊 [Init] Аудиосессия активирована")
        } catch {
            print("❌ [Init] Ошибка активации аудиосессии: \(error)")
        }
    }
    
    
    // MARK: - Универсальный метод воспроизведения трека любого типа
    
    func play(track: any TrackDisplayable) {
        Task {
            do {
                let resolvedURL: URL
                
                if let libraryTrack = track as? LibraryTrack {
                    print("📀 Это LibraryTrack")
                    guard let resolved = libraryTrack.startAccessingIfNeeded() else {
                        print("⛔️ Не удалось открыть доступ к LibraryTrack")
                        return
                    }
                    resolvedURL = resolved
                    print("🌐 resolvedURL.scheme:", resolvedURL.scheme ?? "nil")
                    print("📁 resolvedURL (LibraryTrack):", resolvedURL.path)
                    print("📂 fileExists:", FileManager.default.fileExists(atPath: resolvedURL.path))
                
                } else if let importedTrack = track as? ImportedTrack {
                    print("📥 Это ImportedTrack")
                    guard importedTrack.startAccessingIfNeeded() else {
                        print("⛔️ Не удалось открыть доступ к ImportedTrack")
                        return
                    }
                    resolvedURL = try importedTrack.resolvedURL()
                } else if let savedTrack = track as? Track {
                    print("💾 Это Track")
                    resolvedURL = savedTrack.url
                } else {
                    print("❓ Неизвестный тип трека: \(type(of: track))")
                    return
                }
                
                if resolvedURL == currentAccessedURL {
                    player.play()
                    return
                }
                
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                
                stopAccessingCurrentTrack()
                currentAccessedURL = resolvedURL
                print("🔓 Доступ получен к \(resolvedURL.lastPathComponent)")
                
                let playerItem = AVPlayerItem(url: resolvedURL)
                print("📦 AVPlayerItem создан. Статус: \(playerItem.status.rawValue)")

                let isPlayable = try await playerItem.asset.load(.isPlayable)
                print("📺 isPlayable:", isPlayable)
                
                player.replaceCurrentItem(with: playerItem)
                NotificationCenter.default.addObserver(
                    forName: .AVPlayerItemFailedToPlayToEndTime,
                    object: playerItem,
                    queue: .main
                ) { notification in
                    if let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error {
                        print("❌ Ошибка воспроизведения до конца: \(error)")
                    } else {
                        print("❌ Неизвестная ошибка воспроизведения")
                    }
                }
                player.play()
                print("▶️ Попытка воспроизведения трека: \(resolvedURL.lastPathComponent)")
                
                // Загрузка длительности
                let asset = await playerItem.asset
                let duration = try await asset.load(.duration)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                let timeRange = try await audioTracks.first?.load(.timeRange)
                
                let fromTrack = timeRange?.duration.seconds
                let fromAsset = duration.seconds
                let fromPlayer = playerItem.duration.seconds
                
                let bestDuration = [fromTrack, fromPlayer, fromAsset]
                    .compactMap { $0 }
                    .filter { $0.isFinite && $0 > 0 }
                    .max() ?? 0
                
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .trackDurationUpdated,
                        object: nil,
                        userInfo: ["duration": bestDuration]
                    )
                }
                
                // Отладка (опционально)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    Task {
                        do {
                            let duration = try await asset.load(.duration)
                            let trueDuration = playerItem.duration.seconds
                            let assetDuration = duration.seconds
                            print("🕵️ trueDuration:", trueDuration, "| assetDuration:", assetDuration)
                        } catch {
                            print("❌ Ошибка при загрузке asset.duration:", error)
                        }
                    }
                }
                
            } catch {
                print("❌ Ошибка воспроизведения: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Освобождение доступа к предыдущему файлу
    
    func stopAccessingCurrentTrack() {
        if let url = currentAccessedURL {
            url.stopAccessingSecurityScopedResource()
            currentAccessedURL = nil
        }
    }
    
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
    
    // Подписка на обновление прогресса воспроизведения
    func observeProgress(update: @escaping (TimeInterval) -> Void) {
        removeTimeObserver() /// чтобы не дублировать
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            update(time.seconds)
        }
    }
    
    // Удаляет наблюдатель за прогрессом
    func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    // MARK: - Обновляет информацию Now Playing (для Control Center / экран блокировки)
    
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
    
    // MARK: - Обработка кнопок: Play/Pause/Next Previous
    
    func setupRemoteCommandCenter(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
    ) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { _ in
            onPlay()
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }
        
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { _ in
            onNext()
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { _ in
            onPrevious()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard
                let self,
                let event = event as? MPChangePlaybackPositionCommandEvent
            else {
                return .commandFailed
            }
            
            print("⏩ Перемотка через центр управления: \(event.positionTime) сек")
            self.seek(to: event.positionTime)
            return .success
        }
    }
    
    // MARK: - Обновляет только текущее время и статус воспроизведения в NowPlayingInfo
    
    func updatePlaybackTimeOnly(currentTime: TimeInterval, isPlaying: Bool) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    }
}
    // MARK: - Расширение для NotificationCenter
    
    extension Notification.Name {
        
        // Уведомление о том, что длительность трека была обновлена
        static let trackDurationUpdated = Notification.Name("trackDurationUpdated")
        
        // Уведомление о завершении текущего трека
        static let trackDidFinish = Notification.Name("trackDidFinish")
    }


    
    
   

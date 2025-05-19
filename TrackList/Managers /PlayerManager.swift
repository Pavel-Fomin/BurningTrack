//
//  PlayerManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import AVFoundation
import Combine
import MediaPlayer

final class PlayerManager {
    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var currentAccessedURL: URL?
    
    // MARK: - Инициализация плеера
    init() {
        configureAudioSession()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }
    
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
    
    func play(track: Track) {
        do {
            let resolvedURL = track.url

            // MARK: - Если этот трек уже играет, просто вызываем play()
            if resolvedURL == currentAccessedURL {
                player.play()
                return
            }
            
            // MARK: - Активация аудиосессии
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            
            // MARK: - Закрываем доступ к предыдущему файлу, если был
            stopAccessingCurrentTrack()
            
            // MARK: - Пытаемся активировать доступ
            let didStart = resolvedURL.startAccessingSecurityScopedResource()
            if didStart {
                currentAccessedURL = resolvedURL
            } else {
                
            }
            
            // MARK: - Запуск воспроизведения
            let playerItem = AVPlayerItem(url: resolvedURL)
            player.replaceCurrentItem(with: playerItem)
            player.play()
            // Загружаем duration из playerItem.asset
            playerItem.asset.loadValuesAsynchronously(forKeys: ["duration"]) {
                var error: NSError?
                let status = playerItem.asset.statusOfValue(forKey: "duration", error: &error)
                if status == .loaded {
                    let asset = playerItem.asset
                    let audioTrack = asset.tracks(withMediaType: .audio).first

                    let fromTrack = audioTrack?.timeRange.duration.seconds
                    let fromAsset = asset.duration.seconds
                    let fromPlayer = playerItem.duration.seconds

                    let duration = [fromTrack, fromPlayer, fromAsset]
                        .compactMap { $0 }
                        .filter { $0.isFinite && $0 > 0 }
                        .max() ?? 0


                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: .trackDurationUpdated,
                            object: nil,
                            userInfo: ["duration": duration]
                        )
                    }
                } else {
                    print("❌ Не удалось загрузить длительность:", error?.localizedDescription ?? "неизвестно")
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let trueDuration = self.player.currentItem?.duration.seconds ?? 0
                let assetDuration = self.player.currentItem?.asset.duration.seconds ?? 0
                print("🕵️ trueDuration:", trueDuration, "| assetDuration:", assetDuration)
            }
            
        } catch {
            print("❌ Ошибка воспроизведения: \(error.localizedDescription)")
            print("🪲 Подробности ошибки: \(error)")
        }
    }
    
    // MARK: - Закрытие предыдущего security scoped ресурса
    func stopAccessingCurrentTrack() {
        if let url = currentAccessedURL {
            url.stopAccessingSecurityScopedResource()
            currentAccessedURL = nil
        }
    }
    
    func pause() {
        player.pause()
    }
    
    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
    }
    
    
    // MARK: - Продолжаем текущий трек без повторного открытия
    func playCurrent() {
        player.play()
    
    }
    
    func observeProgress(update: @escaping (TimeInterval) -> Void) {
        removeTimeObserver() // чтобы не дублировать

        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            update(time.seconds)
        }
    }

    func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    func updateNowPlayingInfo(track: Track, currentTime: TimeInterval, duration: TimeInterval) {
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
    
    func setupRemoteCommandCenter(/// обработка кнопок: Play/Pause/Next Previous
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
    
    func updatePlaybackTimeOnly(currentTime: TimeInterval, isPlaying: Bool) {
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
    }

}


// MARK: - Расширение для NotificationCenter
extension Notification.Name {
    static let trackDurationUpdated = Notification.Name("trackDurationUpdated")
    static let trackDidFinish = Notification.Name("trackDidFinish")
}

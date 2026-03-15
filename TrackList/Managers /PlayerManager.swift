//
//  PlayerManager.swift
//  TrackList
//
//  Управляет воспроизведением через AVPlayer.
//  - доступ к файлам (security-scoped URL)
//  - подготовка и воспроизведение
//  - прогресс воспроизведения
//  - Now Playing Info
//  - уведомления trackDidFinish / trackDurationUpdated
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import Combine
import MediaPlayer
@preconcurrency import AVFoundation

final class PlayerManager {

    // MARK: - Private

    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var currentAccessedURL: URL?

    // MARK: - Состояние трека

    /// ID текущего трека, загруженного в плеер (не обязательно играет).
    private(set) var currentTrackId: UUID?

    /// Флаг, что плеер сейчас воспроизводит трек.
    private(set) var isPlaying: Bool = false

    // MARK: - Init

    init() {
        print("🧠 PlayerManager инициализирован")

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(trackDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
    }

    // MARK: - Finish Notification

    @objc private func trackDidFinishPlaying() {
        // Трек доиграл до конца — считаем, что больше не играет
        isPlaying = false
        NotificationCenter.default.post(name: .trackDidFinish, object: nil)
    }

    // MARK: - Main Playback

    func play(track: any TrackDisplayable) {
        Task {
            let trackId = track.id

            // 1. resolvedURL — через BookmarkResolver
            guard let resolvedURL = await BookmarkResolver.url(forTrack: trackId) else {
                print("❌ Нет URL в BookmarksRegistry для \(trackId)")
                PersistentLogger.log("❌ PlayerManager: no URL for trackId=\(trackId)")
                return
            }

            // 2. Активация аудиосессии
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("❌ Ошибка активации аудиосессии: \(error)")
            }

            // 3. Закрываем старый доступ
            stopAccessingCurrentTrack()

            // 4. Открываем новый доступ
            // 4. Пытаемся открыть доступ к файлу.
            // В iOS 26 (File Provider Storage) startAccessing на файл может вернуть false,
            // при этом доступ может быть получен через root-scope папки.
            let started = resolvedURL.startAccessingSecurityScopedResource()
            if started {
                currentAccessedURL = resolvedURL
            } else {
                currentAccessedURL = nil
                print("⚠️ startAccessing вернул false для файла, пробуем играть через root-scope:", resolvedURL.lastPathComponent)
                PersistentLogger.log("⚠️ PlayerManager: startAccessing false file=\(resolvedURL.lastPathComponent)")
            }

            // 5. Создаём AVPlayerItem
            let item = AVPlayerItem(url: resolvedURL)

            do {
                _ = try await item.asset.load(.isPlayable)
            } catch {
                print("❌ Трек не проигрывается: \(error)")
                PersistentLogger.log("❌ PlayerManager: not playable error=\(error)")
                return
            }

            // 6. Подключаем item и играем
            player.replaceCurrentItem(with: item)
            player.play()
            PersistentLogger.log("▶️ PlayerManager: play started track=\(resolvedURL.lastPathComponent)")

            // Обновляем состояние текущего трека
            currentTrackId = trackId
            isPlaying = true

            // 7. Читаем длительность трека
            let duration = (try? await item.asset.load(.duration))?.seconds ?? 0

            await MainActor.run {
                NotificationCenter.default.post(
                    name: .trackDurationUpdated,
                    object: nil,
                    userInfo: ["duration": duration]
                )
            }
        }
    }

    // MARK: - Security Access

    func stopAccessingCurrentTrack() {
        if let url = currentAccessedURL {
            url.stopAccessingSecurityScopedResource()
            currentAccessedURL = nil
        }
    }

    // MARK: - Controls

    func pause() {
        player.pause()
        isPlaying = false
    }

    func playCurrent() {
        player.play()
        if player.currentItem != nil {
            isPlaying = true
        }
    }

    func seek(to time: TimeInterval) {
        let cm = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cm)
    }

    // MARK: - Признак занятости трека

    /// Возвращает `true`, если указанный трек сейчас загружен в плеер
    /// (даже если стоит на паузе) и держит security-scoped доступ к файлу.
    func isBusy(_ id: UUID) -> Bool {
        return currentTrackId == id && currentAccessedURL != nil
    }

    // MARK: - Progress

    func observeProgress(update: @escaping (TimeInterval) -> Void) {
        removeTimeObserver()
        let interval = CMTimeMakeWithSeconds(1.0, preferredTimescale: 600)

        timeObserverToken = player.addPeriodicTimeObserver(
            forInterval: interval,
            queue: .main
        ) { time in
            update(time.seconds)
        }
    }

    func removeTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }

    // MARK: - Remote Command Center

    func setupRemoteCommandCenter(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
    ) {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { _ in
            onPlay()
            return .success
        }

        center.pauseCommand.addTarget { _ in
            onPause()
            return .success
        }

        center.nextTrackCommand.addTarget { _ in
            onNext()
            return .success
        }

        center.previousTrackCommand.addTarget { _ in
            onPrevious()
            return .success
        }
        
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard
                let self,
                let event = event as? MPChangePlaybackPositionCommandEvent
            else { return .commandFailed }
            
            let time = event.positionTime
            self.seek(to: time)
            
            return .success
        }
    }

    // MARK: - Now Playing Info

    /// Применяет полный snapshot в Control Center.
    /// PlayerManager НЕ решает, какие данные показывать — он только применяет.
    func applyNowPlaying(snapshot: NowPlayingSnapshot) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: snapshot.title,
            MPMediaItemPropertyArtist: snapshot.artist,
            MPMediaItemPropertyPlaybackDuration: snapshot.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: snapshot.currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: snapshot.isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]
        
        if let artwork = snapshot.artwork {
            info[MPMediaItemPropertyArtwork] =
                MPMediaItemArtwork(boundsSize: CGSize(width: artwork.width, height: artwork.height)) { _ in
                    UIImage(cgImage: artwork)
                }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// Обновляет только время и playbackRate, не трогая остальную карточку.
    func applyPlaybackTime(currentTime: TimeInterval, isPlaying: Bool) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

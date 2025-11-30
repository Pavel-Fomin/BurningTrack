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
        NotificationCenter.default.post(name: .trackDidFinish, object: nil)
    }

    // MARK: - Main Playback

    func play(track: any TrackDisplayable) {
        Task {
            // 1. resolvedURL — теперь через BookmarkResolver
            guard let resolvedURL = await BookmarkResolver.url(forTrack: track.id) else {
                print("❌ Нет URL в BookmarksRegistry для \(track.id)")
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
            guard resolvedURL.startAccessingSecurityScopedResource() else {
                print("⚠️ Нет доступа к файлу \(resolvedURL.lastPathComponent)")
                return
            }
            currentAccessedURL = resolvedURL

            // 5. Создаём AVPlayerItem
            let item = AVPlayerItem(url: resolvedURL)

            do {
                _ = try await item.asset.load(.isPlayable)
            } catch {
                print("❌ Трек не проигрывается: \(error)")
                return
            }

            // 6. Подключаем item и играем
            player.replaceCurrentItem(with: item)
            player.play()

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

    func pause() { player.pause() }
    func playCurrent() { player.play() }

    func seek(to time: TimeInterval) {
        let cm = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cm)
    }

    // MARK: - Progress

    func observeProgress(update: @escaping (TimeInterval) -> Void) {
        removeTimeObserver()
        let interval = CMTime(seconds: 0.5, preferredTimescale: 1_000_000_000)

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
    }

    // MARK: - Now Playing Info

    func updateNowPlayingInfo(track: any TrackDisplayable,
                              currentTime: TimeInterval,
                              duration: TimeInterval) {

        let info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title ?? track.fileName,
            MPMediaItemPropertyArtist: track.artist ?? "",
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue
        ]

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    func updatePlaybackTimeOnly(currentTime: TimeInterval, isPlaying: Bool) {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

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


final class PlayerManager {
    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var currentAccessedURL: URL?

    init() {
        print("🧠 PlayerManager инициализирован")

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

    func play(track: any TrackDisplayable) {
        Task {
            // 1. Получаем URL ИСКЛЮЧИТЕЛЬНО из TrackRegistry
            guard let resolvedURL = await TrackRegistry.shared.resolvedURL(for: track.id) else {
                print("❌ Нет URL в TrackRegistry для \(track.id)")
                return
            }

            // 2. Настройка аудиосессии
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("❌ Ошибка активации аудиосессии: \(error)")
            }

            // 3. Закрываем старый доступ
            stopAccessingCurrentTrack()

            // 4. Открываем доступ
            guard resolvedURL.startAccessingSecurityScopedResource() else {
                print("⚠️ Нет доступа к файлу \(resolvedURL.lastPathComponent)")
                return
            }
            currentAccessedURL = resolvedURL

            // 5. Подготавливаем item
            let item = AVPlayerItem(url: resolvedURL)

            do {
                _ = try await item.asset.load(.isPlayable)
            } catch {
                print("❌ Трек не проигрывается: \(error)")
                return
            }

            // 6. Назначаем и играем
            player.replaceCurrentItem(with: item)
            player.play()

            // 7. Длительность
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

    func stopAccessingCurrentTrack() {
        if let url = currentAccessedURL {
            url.stopAccessingSecurityScopedResource()
            currentAccessedURL = nil
        }
    }

    func pause() { player.pause() }
    func playCurrent() { player.play() }

    func seek(to time: TimeInterval) {
        let cm = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cm)
    }

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
}

// MARK: - Notifications

extension Notification.Name {
    static let trackDurationUpdated = Notification.Name("trackDurationUpdated")
    static let trackDidFinish = Notification.Name("trackDidFinish")
}

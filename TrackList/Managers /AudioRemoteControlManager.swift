//
//  AudioRemoteControlManager.swift..swift
//  TrackList
//
//  Created by Pavel Fomin on 11.04.2025.
//
import Foundation
import MediaPlayer
import AVFoundation

// MARK: - Расширение для удобной работы с уведомлениями переключения треков
extension Notification.Name {
    static let nextTrack = Notification.Name("nextTrack")
    static let previousTrack = Notification.Name("previousTrack")
}

class AudioRemoteControlManager {
    static let shared = AudioRemoteControlManager()
    
    private init() { }
    
    func setupRemoteCommands(for player: AVPlayer) {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // MARK: - Обработка команды Play
        commandCenter.playCommand.addTarget { [weak player] event in
            player?.play()
            return .success
        }
        
        // MARK: - Обработка команды Pause
        commandCenter.pauseCommand.addTarget { [weak player] event in
            player?.pause()
            return .success
        }
        
        // MARK: - Команда Next Track – отправляем уведомление для переключения трека
        commandCenter.nextTrackCommand.addTarget { event in
            NotificationCenter.default.post(name: .nextTrack, object: nil)
            return .success
        }
        
        // MARK: - Команда Previous Track – отправляем уведомление для переключения трека
        commandCenter.previousTrackCommand.addTarget { event in
            NotificationCenter.default.post(name: .previousTrack, object: nil)
            return .success
        }
        
        // MARK: - Команда изменения позиции воспроизведения (по ползунку)
        commandCenter.changePlaybackPositionCommand.addTarget { [weak player] event in
            if let event = event as? MPChangePlaybackPositionCommandEvent,
               let player = player {
                let targetTime = CMTime(seconds: event.positionTime, preferredTimescale: 600)
                player.seek(to: targetTime)
                return .success
            }
            return .commandFailed
        }
    }
}

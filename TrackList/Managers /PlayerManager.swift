//
//  PlayerManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import AVFoundation
import Combine

final class PlayerManager {
    private let player = AVPlayer()
    private var timeObserverToken: Any?
    private var currentAccessedURL: URL?
    
    // MARK: - Инициализация плеера
    init() {
        configureAudioSession()
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
    
    func addPeriodicTimeObserver(update: @escaping (TimeInterval) -> Void) {
        removePeriodicTimeObserver()
        let interval = CMTime(seconds: 1.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { _ in
            let seconds = self.player.currentTime().seconds
            update(seconds)
        }
    }
    
    func removePeriodicTimeObserver() {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    // MARK: - Продолжаем текущий трек без повторного открытия
    func playCurrent() {
        player.play()
    
    }
}

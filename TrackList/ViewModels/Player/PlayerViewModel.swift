//
//  PlayerViewModel.swift
//  TrackList
//
//  ViewModel для управления воспроизведением:
//  - старт/пауза, перемотка, следующий/предыдущий
//  - наблюдение за прогрессом
//  - взаимодействие с Control Center и NowPlayingInfo
//
//  Работает с абстрактным протоколом TrackDisplayable и тремя контекстами:
//  - PlayerTrack (плейлист плеера)
//  - Track (треклист)
//  - LibraryTrack (фонотека)
//
//  Created by Pavel Fomin on 28.04.2025.
//


import Foundation
import AVFoundation

@MainActor
final class PlayerViewModel: ObservableObject {
    
    // MARK: - Публичные состояния
   
    @Published var currentTrackDisplayable: (any TrackDisplayable)?  /// Текущий воспроизводимый трек (PlayerTrack / Track / LibraryTrack)
    @Published var isPlaying: Bool = false                           /// Воспроизводится ли сейчас аудио
    @Published var currentTime: TimeInterval = 0.0                   /// Текущее время воспроизведения
    @Published var trackDuration: TimeInterval = 0.0                 /// Длительность текущего трека
    @Published var currentContext: PlaybackContext?                  /// Контекст воспроизведения (плеер / треклист / фонотека)
    
    // MARK: - Внутренние зависимости
    
    let playerManager = PlayerManager()
    private var playerTracksContext: [PlayerTrack] = []     /// Контекст плеера (player.json)
    private var trackListContext: [Track] = []              /// Контекст треклиста
    private var libraryTracksContext: [LibraryTrack] = []   /// Контекст фонотеки
    
    
    // MARK: - Инициализация
    
    init() {
        // Обновление длительности трека
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
        
        // Автопереход к следующему треку по завершении
        NotificationCenter.default.addObserver(
            forName: .trackDidFinish,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.playNextTrack() }
        }
        
        // Настройка Remote Command Center
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
    
    /// Запуск воспроизведения трека в заданном контексте
    func play(track: any TrackDisplayable, context: [any TrackDisplayable] = []) {
        
        // Определяем контекст воспроизведения
        let contextType = PlaybackContext.detect(from: context)
        currentContext = contextType
        
        // Если это тот же самый трек и тот же тип — просто продолжить
        if let current = currentTrackDisplayable,
           current.id == track.id,
           type(of: current) == type(of: track) {
            playerManager.playCurrent()
            isPlaying = true
            return
        }
        
        // Новый трек: останавливаем доступ к старому
        playerManager.stopAccessingCurrentTrack()
        currentTrackDisplayable = track
        currentTime = 0
        trackDuration = 0
        
        // Обновляем контексты
        if track is PlayerTrack {
            playerTracksContext = context.compactMap { $0 as? PlayerTrack }
            trackListContext = []
            libraryTracksContext = []
        } else if track is Track {
            trackListContext = context.compactMap { $0 as? Track }
            playerTracksContext = []
            libraryTracksContext = []
        } else if track is LibraryTrack {
            libraryTracksContext = context.compactMap { $0 as? LibraryTrack }
            trackListContext = []
            playerTracksContext = []
        } else {
            // Неизвестный тип — на всякий случай чистим всё
            playerTracksContext = []
            trackListContext = []
            libraryTracksContext = []
        }
        
        // Стартуем воспроизведение через PlayerManager
        playerManager.play(track: track)
        
        // Первичное заполнение Now Playing Info (duration ещё может быть 0)
        playerManager.updateNowPlayingInfo(
            track: track,
            currentTime: 0,
            duration: trackDuration
        )
        
        // Через полсекунды — ещё одно обновление с актуальной длительностью
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self,
                  let current = self.currentTrackDisplayable else { return }
            
            self.playerManager.updateNowPlayingInfo(
                track: current,
                currentTime: self.currentTime,
                duration: self.trackDuration
            )
        }
        
        // Наблюдаем прогресс воспроизведения
        playerManager.observeProgress { [weak self] time in
            guard let self else { return }
            self.currentTime = time
            self.playerManager.updatePlaybackTimeOnly(
                currentTime: time,
                isPlaying: self.isPlaying
            )
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
        currentTime = time
    }
    
    
    // MARK: - Переход между треками
    
    /// Следующий трек в текущем контексте
    func playNextTrack() {
        guard let current = currentTrackDisplayable else { return }
        
        if let libTrack = current as? LibraryTrack {
            guard let index = libraryTracksContext.firstIndex(where: { $0.id == libTrack.id }),
                  index + 1 < libraryTracksContext.count else { return }
            
            play(track: libraryTracksContext[index + 1], context: libraryTracksContext)
            
        } else if let track = current as? Track {
            guard let index = trackListContext.firstIndex(where: { $0.id == track.id }),
                  index + 1 < trackListContext.count else { return }
            
            play(track: trackListContext[index + 1], context: trackListContext)
            
        } else if let playerTrack = current as? PlayerTrack {
            guard let index = playerTracksContext.firstIndex(where: { $0.id == playerTrack.id }),
                  index + 1 < playerTracksContext.count else { return }
            
            play(track: playerTracksContext[index + 1], context: playerTracksContext)
        }
    }
    
    /// Предыдущий трек в текущем контексте
    func playPreviousTrack() {
        guard let current = currentTrackDisplayable else { return }
        
        if let libTrack = current as? LibraryTrack {
            guard let index = libraryTracksContext.firstIndex(where: { $0.id == libTrack.id }),
                  index - 1 >= 0 else { return }
            
            play(track: libraryTracksContext[index - 1], context: libraryTracksContext)
            
        } else if let track = current as? Track {
            guard let index = trackListContext.firstIndex(where: { $0.id == track.id }),
                  index - 1 >= 0 else { return }
            
            play(track: trackListContext[index - 1], context: trackListContext)
            
        } else if let playerTrack = current as? PlayerTrack {
            guard let index = playerTracksContext.firstIndex(where: { $0.id == playerTrack.id }),
                  index - 1 >= 0 else { return }
            
            play(track: playerTracksContext[index - 1], context: playerTracksContext)
        }
    }
    
    
    // MARK: - Проверка "текущего" трека
    
    func isCurrent(_ track: any TrackDisplayable, in context: PlaybackContext) -> Bool {
        guard let current = currentTrackDisplayable,
              let currentCtx = currentContext else { return false }
        
        return current.id == track.id && currentCtx == context
    }
    
    
    // MARK: - Деинициализация
    
    deinit {
        playerManager.removeTimeObserver()
        NotificationCenter.default.removeObserver(self)
    }
}

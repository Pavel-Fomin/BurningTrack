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
import UIKit
import QuartzCore

@MainActor
final class PlayerViewModel: ObservableObject {
    
    // MARK: - Публичные состояния
    
    @Published var currentTrackDisplayable: (any TrackDisplayable)?  /// Текущий воспроизводимый трек (PlayerTrack / Track / LibraryTrack)
    @Published var isPlaying: Bool = false                           /// Воспроизводится ли сейчас аудио
    @Published var currentTime: TimeInterval = 0.0                   /// Текущее время воспроизведения
    @Published var trackDuration: TimeInterval = 0.0                 /// Длительность текущего трека
    @Published var currentContext: PlaybackContext?                  /// Контекст воспроизведения (плеер / треклист / фонотека)
    @Published private(set) var metadataByTrackId: [UUID: TrackMetadataCacheManager.CachedMetadata] = [:]
    
    private var nowPlayingArtworkByTrackId: [UUID: CGImage] = [:]
    
    // MARK: - MiniPlayer State
    
    /// Статическое состояние мини-плеера (обновляется редко).
    /// В Шаге 4 сюда добавим сборку artwork через MiniPlayerStateBuilder.
    @Published private(set) var miniPlayerStaticState: MiniPlayerStaticState?
    
    @Published private(set) var miniPlayerIsPlaying: Bool = false
    @Published private(set) var miniPlayerCurrentTime: TimeInterval = 0
    @Published private(set) var miniPlayerDuration: TimeInterval = 0
    
    // MARK: - Throttling
    
    private var lastMiniPlayerTick: CFTimeInterval = 0
    private var lastNowPlayingTick: CFTimeInterval = 0
    
    // MARK: - Внутренние зависимости
    
    let playerManager = PlayerManager()
    private var playerTracksContext: [PlayerTrack] = []     /// Контекст плеера
    private var trackListContext: [Track] = []              /// Контекст треклиста
    private var libraryTracksContext: [LibraryTrack] = []   /// Контекст фонотеки
    
    // MARK: - Now Playing Snapshot
    
    /// Собирает snapshot для Control Center из текущего состояния.
    /// Источник метаданных — TrackMetadataCacheManager.
    /// Artwork используется отдельного размера (~512 px).
    private func makeNowPlayingSnapshot(for track: any TrackDisplayable) -> NowPlayingSnapshot {
        
        let metadata = metadataByTrackId[track.id]
        
        return NowPlayingSnapshot(
            title: metadata?.title ?? track.fileName,
            artist: metadata?.artist ?? "",
            artwork: nowPlayingArtworkByTrackId[track.id],
            currentTime: currentTime,
            duration: metadata?.duration ?? trackDuration,
            isPlaying: isPlaying
        )
    }
    
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
                    guard let self else { return }
                    
                    self.trackDuration = duration
                    self.updateMiniPlayerProgressState()
                    
                    // Если есть текущий трек — пересобираем snapshot
                    if let current = self.currentTrackDisplayable {
                        self.playerManager.applyNowPlaying(
                            snapshot: self.makeNowPlayingSnapshot(for: current)
                        )
                    }
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
        // Обновление метаданных трека (после редактирования тегов / rename)
        NotificationCenter.default.addObserver(
            forName: .trackMetadataDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let trackId = notification.object as? UUID else { return }
            
            Task { @MainActor in
                self.metadataByTrackId[trackId] = nil
                self.nowPlayingArtworkByTrackId[trackId] = nil
                self.requestMetadataIfNeeded(for: trackId)
            }
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
    
    // MARK: - Metadata
    
    // Реализация метода чтения (контракт)
    func metadata(for trackId: UUID)
    -> TrackMetadataCacheManager.CachedMetadata?
    {
        metadataByTrackId[trackId]
    }
    
    // Реализация запроса загрузки (контракт)
    func requestMetadataIfNeeded(for trackId: UUID) {
        
        if metadataByTrackId[trackId] != nil { return }
        
        Task {
            // URL резолвим ОДИН раз
            guard let url = await BookmarkResolver.url(forTrack: trackId) else { return }
            
            // 1. Метаданные (title / artist / duration)
            let meta = await TrackMetadataCacheManager.shared.loadMetadata(for: url)
            
            if let meta {
                await MainActor.run {
                    metadataByTrackId[trackId] = meta
                    
                    if let current = currentTrackDisplayable,
                       current.id == trackId {
                        self.updateMiniPlayerStaticState(for: current)
                        playerManager.applyNowPlaying(
                            snapshot: makeNowPlayingSnapshot(for: current)
                        )
                    }
                }
            }
            
            // 2. Большой artwork для Lock Screen / Control Center (512px)
            // Берём СЫРЫЕ данные из кэша метаданных и строим CGImage через ImageDownsampler.
            let nowPlayingCGImage: CGImage? = {
                guard let data = meta?.artworkData else { return nil }
                return makeThumbnail(from: data, maxPixel: ArtworkPurposeSizes.maxPixel(for: .nowPlaying))
            }()
            
            await MainActor.run {
                if let nowPlayingCGImage {
                    nowPlayingArtworkByTrackId[trackId] = nowPlayingCGImage
                }
                
                if let current = currentTrackDisplayable,
                   current.id == trackId {
                    playerManager.applyNowPlaying(
                        snapshot: makeNowPlayingSnapshot(for: current)
                    )
                }
            }
        }
    }
    
    // MARK: - MiniPlayer State Updates
    
    /// Пересобирает статическое состояние мини-плеера из текущего трека и кэша метаданных.
    /// ВАЖНО: в Шаге 4 сюда добавим artwork через MiniPlayerStateBuilder.
    private func updateMiniPlayerStaticState(for track: any TrackDisplayable) {
        
        let metadata = metadataByTrackId[track.id]
        
        miniPlayerStaticState = MiniPlayerStateBuilder.buildStaticState(
            track: track,
            metadata: metadata
        )
    }
    
    /// Пересобирает прогресс-состояние мини-плеера из текущих публичных полей.
    private func updateMiniPlayerProgressState() {
        miniPlayerIsPlaying = isPlaying
        miniPlayerCurrentTime = currentTime
        miniPlayerDuration = trackDuration
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
        requestMetadataIfNeeded(for: track.id)
        
        updateMiniPlayerStaticState(for: track)
        updateMiniPlayerProgressState()
        
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
        
        isPlaying = true
        updateMiniPlayerProgressState()
        
        // Первичное заполнение Now Playing Info (duration ещё может быть 0)
        playerManager.applyNowPlaying(snapshot: makeNowPlayingSnapshot(for: track))
        
        // Наблюдаем прогресс воспроизведения
        playerManager.observeProgress { [weak self] time in
            guard let self else { return }
            
            self.currentTime = time
            
            let now = CACurrentMediaTime()
            
            // UI прогресс: ~20 Hz
            if now - self.lastMiniPlayerTick >= 1.0 {
                self.lastMiniPlayerTick = now
                self.updateMiniPlayerProgressState()
            }
            
            // Now Playing: 1 Hz
            if now - self.lastNowPlayingTick >= 1.0 {
                self.lastNowPlayingTick = now
                self.playerManager.applyPlaybackTime(currentTime: time, isPlaying: self.isPlaying)
            }
        }
        
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
        updateMiniPlayerProgressState()

        lastNowPlayingTick = 0
        playerManager.applyPlaybackTime(currentTime: currentTime, isPlaying: isPlaying)

        if let current = currentTrackDisplayable {
            playerManager.applyNowPlaying(snapshot: makeNowPlayingSnapshot(for: current))
        }
    }

    func seek(to time: TimeInterval) {
        playerManager.seek(to: time)
        currentTime = time
        updateMiniPlayerProgressState()

        lastNowPlayingTick = 0
        playerManager.applyPlaybackTime(currentTime: time, isPlaying: isPlaying)

        if let current = currentTrackDisplayable {
            playerManager.applyNowPlaying(snapshot: makeNowPlayingSnapshot(for: current))
        }
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
        
        if currentTime > 3 {
               seek(to: 0)
               return
           }
        
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

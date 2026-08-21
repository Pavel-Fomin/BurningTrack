//
//  MiniPlayerPlaybackCapabilities.swift
//  TrackList
//
//  Узкие capability состояния и команд MiniPlayer.
//
//  Created by Pavel Fomin on 10.08.2026.
//

import Foundation

/// Предоставляет только готовые playback-данные, необходимые MiniPlayer presentation-feature.
/// Контракт не раскрывает очередь, PlayerManager, persistence или произвольные команды плеера.
@MainActor
protocol MiniPlayerPlaybackProviding: AnyObject {
    /// Текущая display-модель нужна только общим действиям «Избранное» и «Показать в фонотеке».
    var currentTrackDisplayable: (any TrackDisplayable)? { get }
    /// Явное состояние представления мини-плеера, сформированное владельцем playback.
    var miniPlayerState: MiniPlayerState { get }
    /// Производное состояние waveform текущего трека.
    var waveformState: PlayerWaveformState { get }
    /// Подтверждённое состояние текущего трека в «Избранном».
    var isCurrentTrackFavorite: Bool { get }
    /// Нормализованный режим текущего playback-контекста.
    var playbackMode: PlaybackMode { get }
}

/// Выполняет только команды, доступные из MiniPlayer, не передавая feature полный PlayerViewModel.
@MainActor
protocol MiniPlayerPlaybackControlling: AnyObject {
    /// Переключает воспроизведение и паузу текущего трека.
    func togglePlayPause()
    /// Переходит к предыдущему треку текущего playback-контекста.
    func playPreviousTrack(reason: ActiveTrackChangeReason)
    /// Переходит к следующему треку текущего playback-контекста.
    func playNextTrack(reason: ActiveTrackChangeReason)
    /// Перематывает текущий трек к указанному времени.
    func seek(to time: TimeInterval)
    /// Переключает режим случайного воспроизведения.
    func toggleShuffle()
    /// Переключает режим повтора всего контекста.
    func toggleRepeatAll()
    /// Переключает режим повтора текущего трека.
    func toggleRepeatOne()
}

/// Выполняет общий маршрут показа трека в фонотеке без раскрытия SheetActionCoordinator feature.
@MainActor
protocol MiniPlayerLibraryRouting: AnyObject {
    /// Запускает существующий сценарий показа трека в фонотеке.
    func showInLibrary(_ track: any TrackDisplayable)
}

extension PlayerViewModel: MiniPlayerPlaybackProviding, MiniPlayerPlaybackControlling {}

extension SheetActionCoordinator: MiniPlayerLibraryRouting {}

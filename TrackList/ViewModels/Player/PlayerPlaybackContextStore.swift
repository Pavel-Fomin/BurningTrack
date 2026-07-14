//
//  PlayerPlaybackContextStore.swift
//  TrackList
//
//  Хранилище текущего контекста воспроизведения.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Абстрагирует синхронное постоянное хранилище режима от playback-механизма.
@MainActor
protocol PlaybackModePersisting: AnyObject {
    func loadPlaybackMode() -> PlaybackMode
    func savePlaybackMode(_ mode: PlaybackMode)
}

/// Хранит текущий контекст воспроизведения.
/// Отвечает только за:
/// - сохранение исходного контекста воспроизведения;
/// - построение playback-порядка через индексы без изменения исходного массива;
/// - применение Shuffle и Repeat к текущему контексту;
/// - поиск следующего и предыдущего трека.
@MainActor
final class PlayerPlaybackContextStore {

    /// Единственный источник данных текущего контекста в исходном порядке.
    private var originalTracks: [any TrackDisplayable] = []

    /// Индексы элементов originalTracks в фактическом порядке воспроизведения.
    private var playbackIndexes: [Int] = []

    /// Текущая позиция в playbackIndexes.
    private var currentPlaybackIndex: Int?

    /// Идентичность контекста нужна, чтобы не сбрасывать Shuffle при переходе к следующему треку.
    private var contextIdentity: ContextIdentity?

    /// Режимы относятся к текущей playback-сессии и не смешиваются с моделями UI или базы данных.
    private(set) var playbackMode: PlaybackMode

    /// Синхронный адаптер постоянных настроек; чтение выполняется до первого контекста.
    private let playbackModePersistence: any PlaybackModePersisting

    private struct ContextIdentity: Equatable {
        let kind: PlaybackContext
        let trackIDs: [UUID]
    }

    /// Создаёт store с уже восстановленным режимом до построения playback-индексов.
    init(
        playbackModePersistence: (any PlaybackModePersisting)? = nil
    ) {
        let resolvedPersistence = playbackModePersistence ?? AppSettingsManager.shared
        self.playbackModePersistence = resolvedPersistence
        self.playbackMode = resolvedPersistence.loadPlaybackMode().normalized
    }

    /// Проверяет, совпадает ли переданный массив с активным контекстом.
    func isCurrentContext(_ context: [any TrackDisplayable]) -> Bool {
        contextIdentity == makeContextIdentity(for: context)
    }

    /// Обновляет контекст воспроизведения и возвращает true для нового контекста.
    func updateContext(
        currentTrack: any TrackDisplayable,
        context: [any TrackDisplayable]
    ) -> Bool {
        guard !context.isEmpty else {
            clear()
            return true
        }

        let newIdentity = makeContextIdentity(for: context)
        guard newIdentity != contextIdentity else {
            currentPlaybackIndex = playbackIndex(for: currentTrack)
            return false
        }

        originalTracks = context
        contextIdentity = newIdentity
        playbackIndexes = makePlaybackIndexes(currentTrack: currentTrack)
        currentPlaybackIndex = playbackIndex(for: currentTrack)
        return true
    }

    /// Атомарно заменяет оба режима и перестраивает только индексный порядок Shuffle.
    func setPlaybackMode(
        _ mode: PlaybackMode,
        currentTrack: (any TrackDisplayable)?
    ) {
        let normalizedMode = mode.normalized
        let shuffleChanged = normalizedMode.isShuffleEnabled != playbackMode.isShuffleEnabled
        playbackMode = normalizedMode

        // Store остаётся единственным владельцем состояния, а запись выполняется централизованно.
        playbackModePersistence.savePlaybackMode(normalizedMode)

        guard shuffleChanged, !originalTracks.isEmpty else { return }

        playbackIndexes = makePlaybackIndexes(currentTrack: currentTrack)
        currentPlaybackIndex = currentTrack.flatMap { track in
            playbackIndex(for: track)
        }
    }

    /// Возвращает следующий трек в текущем контексте.
    func nextTrack(after currentTrack: any TrackDisplayable) -> (track: any TrackDisplayable, context: [any TrackDisplayable])? {
        guard !playbackIndexes.isEmpty,
              let resolvedCurrentIndex = playbackIndex(for: currentTrack) else {
            return nil
        }
        currentPlaybackIndex = resolvedCurrentIndex
        guard let currentIndex = currentPlaybackIndex else { return nil }

        let nextIndex: Int
        if currentIndex + 1 < playbackIndexes.count {
            nextIndex = currentIndex + 1
        } else if playbackMode.repeatMode == .all {
            nextIndex = 0
        } else {
            return nil
        }

        currentPlaybackIndex = nextIndex
        let originalIndex = playbackIndexes[nextIndex]
        return (originalTracks[originalIndex], originalTracks)
    }

    /// Возвращает предыдущий трек в текущем контексте.
    func previousTrack(before currentTrack: any TrackDisplayable) -> (track: any TrackDisplayable, context: [any TrackDisplayable])? {
        guard !playbackIndexes.isEmpty,
              let resolvedCurrentIndex = playbackIndex(for: currentTrack) else {
            return nil
        }
        currentPlaybackIndex = resolvedCurrentIndex
        guard let currentIndex = currentPlaybackIndex else { return nil }

        let previousIndex: Int
        if currentIndex > 0 {
            previousIndex = currentIndex - 1
        } else if playbackMode.repeatMode == .all {
            previousIndex = playbackIndexes.count - 1
        } else {
            return nil
        }

        currentPlaybackIndex = previousIndex
        let originalIndex = playbackIndexes[previousIndex]
        return (originalTracks[originalIndex], originalTracks)
    }

    /// Очищает все контексты.
    func clear() {
        originalTracks = []
        playbackIndexes = []
        currentPlaybackIndex = nil
        contextIdentity = nil
    }

    /// Возвращает все известные trackId из текущих контекстов.
    func allTrackIds(currentTrack: (any TrackDisplayable)?) -> Set<UUID> {
        var ids = Set<UUID>()

        if let currentTrack,
           !currentTrack.isPurchasedITunesRuntimeTrack {
            ids.insert(currentTrack.trackId)
        }

        for track in originalTracks {
            guard !track.isPurchasedITunesRuntimeTrack else { continue }
            ids.insert(track.trackId)
        }

        return ids
    }

    // MARK: - Индексный порядок

    /// Создаёт playback-порядок, оставляя текущий трек первым при включении Shuffle.
    private func makePlaybackIndexes(
        currentTrack: (any TrackDisplayable)?
    ) -> [Int] {
        let allIndexes = Array(originalTracks.indices)

        guard playbackMode.isShuffleEnabled else {
            return allIndexes
        }

        guard let currentTrack,
              let currentOriginalIndex = originalTracks.firstIndex(where: { $0.id == currentTrack.id }) else {
            var shuffledIndexes = allIndexes
            shuffledIndexes.shuffle()
            return shuffledIndexes
        }

        var remainingIndexes = allIndexes.filter { $0 != currentOriginalIndex }
        remainingIndexes.shuffle()
        return [currentOriginalIndex] + remainingIndexes
    }

    /// Возвращает позицию исходного трека в текущем playback-порядке.
    private func playbackIndex(
        for track: any TrackDisplayable
    ) -> Int? {
        guard let originalIndex = originalTracks.firstIndex(where: { $0.id == track.id }) else {
            return nil
        }

        return playbackIndexes.firstIndex(of: originalIndex)
    }

    /// Строит стабильный идентификатор контекста по типу и исходному порядку элементов.
    private func makeContextIdentity(
        for context: [any TrackDisplayable]
    ) -> ContextIdentity {
        ContextIdentity(
            kind: PlaybackContext.detect(from: context),
            trackIDs: context.map { $0.id }
        )
    }
}

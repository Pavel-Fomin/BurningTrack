//
//  LibraryTrackPlaybackStateController.swift
//  TrackList
//
//  Точечное состояние воспроизведения для строк фонотеки.
//
//  Created by Pavel Fomin on 22.07.2026.
//

import Combine
import Foundation

/// Публикует для фонотеки только изменения текущего трека, контекста и play/pause.
@MainActor
final class LibraryTrackPlaybackStateController: ObservableObject {

    // MARK: - Состояние

    /// Идентификатор текущего отображаемого элемента плеера.
    @Published private(set) var currentDisplayableId: UUID?
    /// Контекст, в котором запущен текущий трек.
    @Published private(set) var currentContext: PlaybackContext?
    /// Воспроизводится ли текущий трек.
    @Published private(set) var isPlaying = false

    // MARK: - Подписки

    /// Хранит узкие подписки и намеренно не наблюдает прогресс воспроизведения.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Инициализация

    init(
        playbackStateProvider: any PlaybackStateProviding
    ) {
        apply(playbackStateProvider.playbackState)

        playbackStateProvider.playbackStatePublisher
            .sink { [weak self] snapshot in
                self?.apply(snapshot)
            }
            .store(in: &cancellables)
    }

    // MARK: - Публичный API

    /// Проверяет, является ли трек текущим именно в контексте фонотеки.
    func isCurrent(
        _ track: LibraryTrack
    ) -> Bool {
        currentDisplayableId == track.id && currentContext == .library
    }

    /// Проверяет, воспроизводится ли текущий трек фонотеки.
    func isPlaying(
        _ track: LibraryTrack
    ) -> Bool {
        isCurrent(track) && isPlaying
    }

    // MARK: - Обновление состояния

    /// Применяет единый снимок и не создаёт независимых подписок на PlayerViewModel.
    private func apply(
        _ snapshot: PlaybackStateSnapshot
    ) {
        updateCurrentDisplayableId(snapshot.currentDisplayableId)
        updateCurrentContext(snapshot.currentContext)
        updatePlaybackState(snapshot.isPlaying)
    }

    /// Не публикует одинаковый идентификатор текущей строки повторно.
    private func updateCurrentDisplayableId(
        _ displayableId: UUID?
    ) {
        guard currentDisplayableId != displayableId else {
            return
        }

        currentDisplayableId = displayableId
    }

    /// Не публикует одинаковый playback-контекст повторно.
    private func updateCurrentContext(
        _ context: PlaybackContext?
    ) {
        guard currentContext != context else {
            return
        }

        currentContext = context
    }

    /// Не публикует одинаковое состояние play/pause повторно.
    private func updatePlaybackState(
        _ isPlaying: Bool
    ) {
        guard self.isPlaying != isPlaying else {
            return
        }

        self.isPlaying = isPlaying
    }
}

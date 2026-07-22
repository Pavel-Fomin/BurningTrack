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

    /// Идентификатор текущего трека плеера.
    @Published private(set) var currentTrackId: UUID?
    /// Контекст, в котором запущен текущий трек.
    @Published private(set) var currentContext: PlaybackContext?
    /// Воспроизводится ли текущий трек.
    @Published private(set) var isPlaying = false

    // MARK: - Подписки

    /// Хранит узкие подписки и намеренно не наблюдает прогресс воспроизведения.
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        playerViewModel: PlayerViewModel
    ) {
        updateCurrentTrackId(playerViewModel.currentTrackDisplayable?.id)
        updateCurrentContext(playerViewModel.currentContext)
        updatePlaybackState(playerViewModel.isPlaying)

        playerViewModel.$currentTrackDisplayable
            .sink { [weak self] track in
                self?.updateCurrentTrackId(track?.id)
            }
            .store(in: &cancellables)

        playerViewModel.$currentContext
            .sink { [weak self] context in
                self?.updateCurrentContext(context)
            }
            .store(in: &cancellables)

        playerViewModel.$isPlaying
            .sink { [weak self] isPlaying in
                self?.updatePlaybackState(isPlaying)
            }
            .store(in: &cancellables)
    }

    // MARK: - Публичный API

    /// Проверяет, является ли трек текущим именно в контексте фонотеки.
    func isCurrent(
        _ track: LibraryTrack
    ) -> Bool {
        currentTrackId == track.id && currentContext == .library
    }

    /// Проверяет, воспроизводится ли текущий трек фонотеки.
    func isPlaying(
        _ track: LibraryTrack
    ) -> Bool {
        isCurrent(track) && isPlaying
    }

    // MARK: - Обновление состояния

    /// Не публикует одинаковый идентификатор текущего трека повторно.
    private func updateCurrentTrackId(
        _ trackId: UUID?
    ) {
        guard currentTrackId != trackId else {
            return
        }

        currentTrackId = trackId
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

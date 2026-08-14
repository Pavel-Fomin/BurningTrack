import Foundation

/// Обрабатывает только воспроизведение строки фонотеки.
@MainActor
struct LibraryTrackPlaybackHandler {
    /// Состояние нужно только для проверки текущей строки фонотеки.
    let playbackStateProvider: any PlaybackStateProviding
    /// Команды запуска и toggle не раскрывают строке PlayerViewModel.
    let playbackController: any TrackPlaybackControlling
    /// Источник передаётся экраном, который сформировал текущий список.
    let source: PlaybackContextSource?

    init(
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling,
        source: PlaybackContextSource? = nil
    ) {
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.source = source
    }

    /// Проверяет, является ли трек текущим в контексте фонотеки.
    func isCurrent(_ track: LibraryTrack) -> Bool {
        playbackStateProvider.currentDisplayableId == track.id
            && playbackStateProvider.currentContext == .library
    }

    /// Проверяет, играет ли текущий трек.
    func isPlaying(_ track: LibraryTrack) -> Bool {
        isCurrent(track) && playbackStateProvider.isPlaying
    }

    /// Обрабатывает тап по строке.
    func handleTap(track: LibraryTrack, context: [LibraryTrack]) {
        if isCurrent(track) {
            playbackController.togglePlayPause()
        } else if let source {
            playbackController.play(
                track: track,
                context: context.map { $0 as any TrackDisplayable },
                source: source
            )
        } else {
            // При отсутствии источника очередь плеера остаётся единственным нейтральным контекстом воспроизведения.
            playbackController.play(
                track: track,
                context: context.map { $0 as any TrackDisplayable },
                source: .playerQueue
            )
        }
    }
}

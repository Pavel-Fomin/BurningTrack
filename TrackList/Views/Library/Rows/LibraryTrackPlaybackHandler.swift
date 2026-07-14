import Foundation

/// Обрабатывает только воспроизведение строки фонотеки.
@MainActor
struct LibraryTrackPlaybackHandler {
    let playerViewModel: PlayerViewModel
    /// Источник передаётся экраном, который сформировал текущий список.
    let source: PlaybackContextSource?

    init(
        playerViewModel: PlayerViewModel,
        source: PlaybackContextSource? = nil
    ) {
        self.playerViewModel = playerViewModel
        self.source = source
    }

    /// Проверяет, является ли трек текущим в контексте фонотеки.
    func isCurrent(_ track: LibraryTrack) -> Bool {
        playerViewModel.isCurrent(track, in: .library)
    }

    /// Проверяет, играет ли текущий трек.
    func isPlaying(_ track: LibraryTrack) -> Bool {
        isCurrent(track) && playerViewModel.isPlaying
    }

    /// Обрабатывает тап по строке.
    func handleTap(track: LibraryTrack, context: [LibraryTrack]) {
        if isCurrent(track) {
            playerViewModel.togglePlayPause()
        } else if let source {
            playerViewModel.play(
                track: track,
                context: context,
                source: source
            )
        } else {
            // Разделы коллекции пока сохраняют прежний playback-путь без нового постоянного источника.
            playerViewModel.play(track: track, context: context)
        }
    }
}

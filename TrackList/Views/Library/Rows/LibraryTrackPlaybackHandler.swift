import Foundation

/// Обрабатывает только воспроизведение строки фонотеки.
@MainActor
struct LibraryTrackPlaybackHandler {
    let playerViewModel: PlayerViewModel

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
        } else {
            playerViewModel.play(track: track, context: context)
        }
    }
}

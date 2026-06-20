import Foundation

/// Действия строки фонотеки.
/// UI сообщает только намерение, выполнение остаётся в handler.
enum LibraryTrackAction {
    case tapRow(track: LibraryTrack, context: [LibraryTrack])
    case tapArtwork(track: LibraryTrack)
    case addToPlayer(trackId: UUID)
    case addToTrackList(track: LibraryTrack)
    case moveToFolder(track: LibraryTrack)
    case rename(trackId: UUID, strategy: FileRenameStrategy)
    case toggleSelection
    case requestSnapshot(trackId: UUID)
}

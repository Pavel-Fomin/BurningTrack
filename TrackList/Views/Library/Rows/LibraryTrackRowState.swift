import UIKit

/// Готовое состояние строки фонотеки для отображения.
/// Не содержит команд и не знает про ViewModel, SheetManager или загрузку metadata.
struct LibraryTrackRowState {
    let track: LibraryTrack
    let isCurrent: Bool
    let isPlaying: Bool
    let isHighlighted: Bool
    let artwork: UIImage?
    let title: String?
    let artist: String?
    let duration: Double?
    let showsSelection: Bool
    let isSelected: Bool
    let showsFileFormat: Bool
    let trackListNames: [String]?
    let cloudAvailabilityState: CloudTrackAvailabilityState?
    let isContentAvailable: Bool
}

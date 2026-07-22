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

    /// Возвращает состояние с точечным iCloud-обновлением без повторной сборки artwork и metadata.
    func replacingCloudAvailabilityState(
        _ cloudAvailabilityState: CloudTrackAvailabilityState?
    ) -> LibraryTrackRowState {
        LibraryTrackRowState(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            artwork: artwork,
            title: title,
            artist: artist,
            duration: duration,
            showsSelection: showsSelection,
            isSelected: isSelected,
            showsFileFormat: showsFileFormat,
            trackListNames: trackListNames,
            cloudAvailabilityState: cloudAvailabilityState,
            isContentAvailable: cloudAvailabilityState?.isContentAvailable ?? track.isAvailable
        )
    }
}

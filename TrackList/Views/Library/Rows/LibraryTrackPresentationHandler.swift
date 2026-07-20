import Foundation

/// Готовит данные отображения строки фонотеки.
@MainActor
struct LibraryTrackPresentationHandler {
    let metadataProvider: TrackMetadataProviding
    let stateBuilder = LibraryTrackRowStateBuilder()

    /// Возвращает runtime snapshot трека.
    func snapshot(for trackId: UUID) -> TrackRuntimeSnapshot? {
        metadataProvider.snapshot(for: trackId)
    }

    /// Запрашивает runtime snapshot, если он ещё не загружен.
    func requestSnapshotIfNeeded(for trackId: UUID) {
        metadataProvider.requestSnapshotIfNeeded(for: trackId)
    }

    /// Собирает состояние строки.
    func makeState(
        track: LibraryTrack,
        snapshot: TrackRuntimeSnapshot?,
        isCurrent: Bool,
        isPlaying: Bool,
        isHighlighted: Bool,
        trackListNames: [String],
        showsSelection: Bool,
        isSelected: Bool,
        shouldShowTags: Bool,
        shouldShowTrackListMembership: Bool,
        shouldShowFileFormat: Bool,
        cloudAvailabilityState: CloudTrackAvailabilityState?
    ) -> LibraryTrackRowState {
        stateBuilder.build(
            track: track,
            snapshot: snapshot,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            trackListNames: trackListNames,
            showsSelection: showsSelection,
            isSelected: isSelected,
            shouldShowTags: shouldShowTags,
            shouldShowTrackListMembership: shouldShowTrackListMembership,
            shouldShowFileFormat: shouldShowFileFormat,
            cloudAvailabilityState: cloudAvailabilityState
        )
    }
}

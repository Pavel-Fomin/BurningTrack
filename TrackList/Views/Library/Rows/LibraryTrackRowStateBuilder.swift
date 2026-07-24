
/// Собирает состояние строки фонотеки из модели трека, runtime snapshot и флагов отображения.
struct LibraryTrackRowStateBuilder {

    /// Собирает готовое состояние строки.
    ///
    /// - Parameters:
    ///   - track: Трек строки.
    ///   - snapshot: Runtime snapshot трека.
    ///   - isCurrent: Является ли трек текущим.
    ///   - isPlaying: Играет ли текущий трек.
    ///   - isHighlighted: Нужно ли подсветить строку.
    ///   - trackListNames: Названия треклистов, где уже есть трек.
    ///   - showsSelection: Показывать ли режим выбора.
    ///   - isSelected: Выбрана ли строка.
    ///   - shouldShowTags: Показывать ли теги.
    ///   - shouldShowTrackListMembership: Показывать ли принадлежность к треклистам.
    ///   - shouldShowFileFormat: Показывать ли формат файла.
    func build(
        track: LibraryTrack,
        snapshot: TrackRuntimeSnapshot?,
        isCurrent: Bool,
        isPlaying: Bool,
        isHighlighted: Bool,
        collectionNavigationTarget: TrackCollectionNavigationTarget?,
        trackListNames: [String],
        showsSelection: Bool,
        isSelected: Bool,
        shouldShowTags: Bool,
        shouldShowTrackListMembership: Bool,
        shouldShowFileFormat: Bool,
        cloudAvailabilityState: CloudTrackAvailabilityState?
    ) -> LibraryTrackRowState {
        let displayFileName = snapshot?.fileName ?? track.fileName
        let artworkRequest = makeArtworkRequest(
            trackId: track.trackId,
            snapshot: snapshot,
            shouldShowTags: shouldShowTags
        )

        return LibraryTrackRowState(
            track: track,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isHighlighted,
            artworkRequest: artworkRequest,
            collectionNavigationTarget: collectionNavigationTarget,
            title: shouldShowTags ? (snapshot?.title ?? track.title ?? displayFileName) : displayFileName,
            artist: shouldShowTags ? (snapshot?.artist ?? track.artist ?? "") : "",
            duration: snapshot?.duration ?? track.duration,
            showsSelection: showsSelection,
            isSelected: isSelected,
            showsFileFormat: shouldShowFileFormat,
            trackListNames: shouldShowTrackListMembership ? trackListNames : nil,
            cloudAvailabilityState: cloudAvailabilityState,
            // Неопределённое iCloud-состояние сохраняет прежнюю доступность модели трека.
            isContentAvailable: cloudAvailabilityState?.isContentAvailable ?? track.isAvailable
        )
    }

    /// Собирает лёгкий запрос обложки строки из runtime snapshot.
    private func makeArtworkRequest(
        trackId: UUID,
        snapshot: TrackRuntimeSnapshot?,
        shouldShowTags: Bool
    ) -> ArtworkRequest? {
        guard shouldShowTags else { return nil }
        return ArtworkRequest(
            trackId: trackId,
            snapshot: snapshot,
            purpose: .trackList
        )
    }
}

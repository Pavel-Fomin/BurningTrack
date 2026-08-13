//
// "LibraryCollectionTracksScreenStore.swift"
// TrackList
// Удерживает screen-local graph списка общего раздела и значения музыкальной коллекции.
// Created by Pavel Fomin on 13.08.2026.
//

import Combine

/// Хранит graph collection-варианта Library Tracks на всё время жизни destination.
/// Стабильный source позволяет контейнеру явно связать StateObject с выбранной коллекцией.
@MainActor
final class LibraryCollectionTracksScreenStore: ObservableObject {
    let source: LibraryTrackListSource
    let tracksViewModel: LibraryTracksViewModel
    let cloudAvailabilityController: LibraryCloudAvailabilityScreenController
    let cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler
    let settingsManager: AppSettingsManager
    let playbackStateController: LibraryTrackPlaybackStateController
    let presentationHandler: LibraryTrackPresentationHandler
    let commandHandler: LibraryTrackCommandHandler
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    let sheetManager: SheetManager

    init(
        source: LibraryTrackListSource,
        tracksViewModel: LibraryTracksViewModel,
        cloudAvailabilityController: LibraryCloudAvailabilityScreenController,
        cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler,
        settingsManager: AppSettingsManager,
        playbackStateController: LibraryTrackPlaybackStateController,
        presentationHandler: LibraryTrackPresentationHandler,
        commandHandler: LibraryTrackCommandHandler,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        sheetManager: SheetManager
    ) {
        self.source = source
        self.tracksViewModel = tracksViewModel
        self.cloudAvailabilityController = cloudAvailabilityController
        self.cloudAvailabilityActionHandler = cloudAvailabilityActionHandler
        self.settingsManager = settingsManager
        self.playbackStateController = playbackStateController
        self.presentationHandler = presentationHandler
        self.commandHandler = commandHandler
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.sheetManager = sheetManager
    }
}

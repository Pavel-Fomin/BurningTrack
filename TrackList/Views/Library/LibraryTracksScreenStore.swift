//
//  LibraryTracksScreenStore.swift
//  TrackList
//
//  Удерживает screen-local graph открытой папки фонотеки.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Combine

/// Хранит объекты folder-варианта Library Tracks на всё время жизни destination.
/// Store не публикует данные экрана: за это отвечает переданная ViewModel,
/// а сам тип нужен StateObject-контейнеру для однократного создания graph.
@MainActor
final class LibraryTracksScreenStore: ObservableObject {
    let tracksViewModel: LibraryTracksViewModel
    let cloudAvailabilityController: LibraryCloudAvailabilityScreenController
    let settingsManager: AppSettingsManager
    let playbackStateController: LibraryTrackPlaybackStateController
    let revealCoordinator: LibraryTrackRevealCoordinator
    let presentationHandler: LibraryTrackPresentationHandler
    let commandHandler: LibraryTrackCommandHandler
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding

    init(
        tracksViewModel: LibraryTracksViewModel,
        cloudAvailabilityController: LibraryCloudAvailabilityScreenController,
        settingsManager: AppSettingsManager,
        playbackStateController: LibraryTrackPlaybackStateController,
        revealCoordinator: LibraryTrackRevealCoordinator,
        presentationHandler: LibraryTrackPresentationHandler,
        commandHandler: LibraryTrackCommandHandler,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    ) {
        self.tracksViewModel = tracksViewModel
        self.cloudAvailabilityController = cloudAvailabilityController
        self.settingsManager = settingsManager
        self.playbackStateController = playbackStateController
        self.revealCoordinator = revealCoordinator
        self.presentationHandler = presentationHandler
        self.commandHandler = commandHandler
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
    }
}

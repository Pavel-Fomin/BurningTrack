//
//  LibraryCloudHandlerIdentityTests.swift
//  TrackListTests
//
//  Проверяет единый stateful iCloud controller для screen lifecycle и row commands destination.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import XCTest
@testable import TrackList

/// Фиксирует contract передачи одного iCloud controller из screen graph в row command handler.
@MainActor
final class LibraryCloudHandlerIdentityTests: XCTestCase {
    /// Row command handler использует тот же stateful controller, что и screen lifecycle handler одного destination.
    func testRowCommandHandlerUsesScreenCloudController() {
        let screenController = LibraryCloudAvailabilityScreenController(
            availabilityController: CloudTrackAvailabilityController(
                manager: LibraryUnavailableCloudManagerSpy()
            )
        )
        let screenHandler = LibraryCloudAvailabilityActionHandler(
            controller: screenController
        )
        let rowHandler = makeRowHandler(
            cloudAvailabilityActionHandler: screenHandler
        )

        XCTAssertTrue(
            rowHandler.cloudAvailabilityActionHandler.controller
                === screenHandler.controller
        )
    }

    /// Собирает row command handler из controlled dependencies, оставляя проверку только на cloud boundary.
    private func makeRowHandler(
        cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler
    ) -> LibraryTrackCommandHandler {
        let toastPresenter = LibraryUnavailableToastPresenterSpy()

        return LibraryTrackCommandHandler(
            sheetManager: SheetManager(),
            playbackHandler: LibraryTrackPlaybackHandler(
                playbackStateProvider: LibraryUnavailablePlaybackStateProviderSpy(),
                playbackController: LibraryUnavailablePlaybackControllerSpy()
            ),
            presentationHandler: LibraryTrackPresentationHandler(
                metadataProvider: LibraryUnavailableMetadataProviderSpy()
            ),
            cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
            collectionNavigationHandler: LibraryUnavailableCollectionNavigatorSpy(),
            trackShareActionHandler: TrackShareActionHandler(
                preparationService: TrackSharePreparationService(),
                viewControllerProvider: LibraryUnavailableViewControllerProviderSpy(),
                toastPresenter: toastPresenter
            ),
            commandExecutor: LibraryUnavailablePlayerAddingSpy(),
            toastManager: toastPresenter,
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: LibraryUnavailableFavoritesServiceSpy()
            ),
            screenActionHandler: LibraryTracksActionHandler(
                output: LibraryUnavailableTracksActionOutputSpy()
            ),
            onRenameTrack: { _, _ in }
        )
    }
}

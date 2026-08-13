// "PlayerUnavailableTrackPresentationTests.swift"
// TrackList
// Контракты presentation-маршрута недоступной строки очереди.
// Created by Pavel Fomin on 13.08.2026.

import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет presentation-route недоступного элемента очереди без запуска playback-flow.
@MainActor
final class PlayerUnavailableTrackPresentationTests: XCTestCase {

    /// Недоступный элемент очереди передаёт единственный Toast и не меняет очередь.
    func testUnavailableQueueItemRoutesToToastWithoutChangingQueue() {
        let track = PlayerTrack(
            queueItemId: UUID(),
            trackId: UUID(),
            title: "Unavailable",
            artist: "Artist",
            duration: 100,
            fileName: "Unavailable.flac",
            isAvailable: false
        )
        let queueStore = PlayerUnavailableQueueStoreSpy()
        let playlistManager = PlaylistManager(
            databaseStore: queueStore,
            loadsInitialQueue: false
        )
        playlistManager.tracks = [track]
        let toastPresenter = PlayerUnavailableToastPresenterSpy()
        let handler = makeHandler(
            playlistManager: playlistManager,
            toastPresenter: toastPresenter
        )

        handler.presentUnavailableTrack(queueItemId: track.queueItemId)

        XCTAssertEqual(toastPresenter.events, [.trackUnavailable(title: "Unavailable")])
        XCTAssertEqual(playlistManager.tracks, [track])
        XCTAssertTrue(queueStore.replacedQueues.isEmpty)
    }

    /// Собирает только presentation-handler с изолированными неиспользуемыми зависимостями.
    private func makeHandler(
        playlistManager: PlaylistManager,
        toastPresenter: PlayerUnavailableToastPresenterSpy
    ) -> PlayerPresentationActionHandler {
        PlayerPresentationActionHandler(
            playlistManager: playlistManager,
            sheetManager: SheetManager(),
            sheetActionCoordinator: PlayerUnavailableSheetActionCoordinatorSpy(),
            toastPresenter: toastPresenter,
            collectionNavigationHandler: PlayerUnavailableCollectionNavigatorSpy(),
            trackShareActionHandler: TrackShareActionHandler(
                preparationService: TrackSharePreparationService(),
                viewControllerProvider: PlayerUnavailableViewControllerProviderSpy(),
                toastPresenter: toastPresenter
            ),
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: PlayerUnavailableFavoritesServiceSpy()
            )
        )
    }
}

/// Хранит очередь в памяти и фиксирует нежелательное сохранение playback-flow.
private final class PlayerUnavailableQueueStoreSpy: PlayerQueuePersisting {
    private(set) var replacedQueues: [[PlayerTrack]] = []

    func fetchQueue() throws -> [PlayerTrack] { [] }

    func replaceQueue(_ tracks: [PlayerTrack]) throws {
        replacedQueues.append(tracks)
    }
}

/// Не открывает navigation-route в проверке недоступного элемента очереди.
@MainActor
private final class PlayerUnavailableSheetActionCoordinatorSpy: PlayerSheetActionCoordinating {
    func showInLibrary(_ track: any TrackDisplayable) {}
}

/// Не открывает значения коллекции в проверке недоступного элемента очереди.
@MainActor
private final class PlayerUnavailableCollectionNavigatorSpy: TrackCollectionIdentifierNavigating {
    func openArtist(trackId: UUID) {}
    func openAlbum(trackId: UUID) {}
}

/// Фиксирует presentation-события без глобального ToastManager.
@MainActor
private final class PlayerUnavailableToastPresenterSpy: ToastPresenting {
    private(set) var errors: [AppError] = []
    private(set) var events: [ToastEvent] = []

    func handle(_ error: AppError) {
        errors.append(error)
    }

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }
}

/// Не предоставляет UIKit presenter, потому что share-flow в тесте не запускается.
@MainActor
private final class PlayerUnavailableViewControllerProviderSpy: ViewControllerProviding {
    func topViewController() -> UIViewController? { nil }
}

/// Реализует неиспользуемые Favorites-команды без persistent storage.
@MainActor
private final class PlayerUnavailableFavoritesServiceSpy: FavoritesServicing {
    func loadFavoriteTrackIds() throws -> Set<UUID> { [] }
    func isFavorite(trackId: UUID) throws -> Bool { false }
    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult { .added }
    func remove(trackId: UUID) throws -> FavoritesMutationResult { .removed }
    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        .unchanged(isFavorite: false)
    }
}

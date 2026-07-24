//
//  TrackCollectionNavigationTests.swift
//  TrackList
//
//  Проверки целей и маршрутов перехода к артисту и альбому из контекстного меню трека.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import XCTest
@testable import TrackList

/// Проверяет подготовку целей из SQLite metadata и межвкладочную навигацию коллекции.
@MainActor
final class TrackCollectionNavigationTests: XCTestCase {

    func testArtistTargetTrimsWhitespace() {
        let target = TrackCollectionNavigationTarget(
            metadata: makeMetadata(artist: "  Boards of Canada  ")
        )

        XCTAssertEqual(target.artist, "Boards of Canada")
    }

    func testMissingArtistDoesNotProduceArtistTarget() {
        let target = TrackCollectionNavigationTarget(
            metadata: makeMetadata(artist: " \n ")
        )

        XCTAssertNil(target.artist)
    }

    func testAlbumTargetTrimsWhitespace() {
        let target = TrackCollectionNavigationTarget(
            metadata: makeMetadata(album: "  Music Has the Right to Children  ")
        )

        XCTAssertEqual(target.album, "Music Has the Right to Children")
    }

    func testMissingAlbumDoesNotProduceAlbumTarget() {
        let target = TrackCollectionNavigationTarget(
            metadata: makeMetadata(album: " \t ")
        )

        XCTAssertNil(target.album)
    }

    func testAlbumTargetPrefersAlbumArtist() {
        let target = TrackCollectionNavigationTarget(
            metadata: makeMetadata(
                artist: "Boards of Canada",
                albumArtist: "  Warp Records  "
            )
        )

        XCTAssertEqual(target.albumArtistKey, "Warp Records")
    }

    func testAlbumTargetFallsBackToArtist() {
        let target = TrackCollectionNavigationTarget(
            metadata: makeMetadata(
                artist: "  Boards of Canada  ",
                albumArtist: " \n "
            )
        )

        XCTAssertEqual(target.albumArtistKey, "Boards of Canada")
    }

    func testCollectionActionsAreUnavailableForPurchasedITunesInPlayer() {
        XCTAssertFalse(
            TrackMenuActionAvailability.isAvailable(
                .goToArtist,
                source: .purchasedITunes,
                context: .player
            )
        )
        XCTAssertFalse(
            TrackMenuActionAvailability.isAvailable(
                .goToAlbum,
                source: .purchasedITunes,
                context: .player
            )
        )
    }

    func testLocalCollectionActionsAreAvailableInRequiredContexts() {
        for context in [TrackMenuContext.player, .library, .trackList] {
            XCTAssertTrue(
                TrackMenuActionAvailability.isAvailable(
                    .goToArtist,
                    source: .library,
                    context: context
                )
            )
            XCTAssertTrue(
                TrackMenuActionAvailability.isAvailable(
                    .goToAlbum,
                    source: .library,
                    context: context
                )
            )
        }
    }

    func testOpenArtistBuildsCategoryAndValueRoute() {
        let coordinator = NavigationCoordinator.shared
        defer { coordinator.libraryPath = [] }

        coordinator.openCollectionValueFromApp(
            category: .artists,
            value: "Boards of Canada"
        )

        XCTAssertEqual(ScenePhaseHandler.shared.activeTab, .library)
        XCTAssertEqual(
            coordinator.libraryPath,
            [
                .collectionCategory(.artists),
                .collectionValue(
                    category: .artists,
                    value: "Boards of Canada",
                    artistKey: nil
                )
            ]
        )

        coordinator.popLibrary()
        XCTAssertEqual(coordinator.libraryPath, [.collectionCategory(.artists)])
    }

    func testOpenAlbumBuildsCategoryAndValueRoute() {
        let coordinator = NavigationCoordinator.shared
        defer { coordinator.libraryPath = [] }

        coordinator.openCollectionValueFromApp(
            category: .albums,
            value: "Music Has the Right to Children",
            artistKey: "Boards of Canada"
        )

        XCTAssertEqual(ScenePhaseHandler.shared.activeTab, .library)
        XCTAssertEqual(
            coordinator.libraryPath,
            [
                .collectionCategory(.albums),
                .collectionValue(
                    category: .albums,
                    value: "Music Has the Right to Children",
                    artistKey: "Boards of Canada"
                )
            ]
        )

        coordinator.popLibrary()
        XCTAssertEqual(coordinator.libraryPath, [.collectionCategory(.albums)])
    }

    /// Создаёт минимальные сохранённые metadata для проверки целей перехода.
    private func makeMetadata(
        artist: String? = "Boards of Canada",
        album: String? = "Music Has the Right to Children",
        albumArtist: String? = nil
    ) -> TrackCachedMetadata {
        TrackCachedMetadata(
            trackId: UUID(),
            title: nil,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            duration: nil,
            year: nil,
            label: nil,
            genre: nil,
            comment: nil
        )
    }
}

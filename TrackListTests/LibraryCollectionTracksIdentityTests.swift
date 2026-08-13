//
// "LibraryCollectionTracksIdentityTests.swift"
// TrackList
// Проверяет стабильную identity destination для collection store.
// Created by Pavel Fomin on 13.08.2026.
//

import XCTest
@testable import TrackList

final class LibraryCollectionTracksIdentityTests: XCTestCase {
    func testAllLibraryTracksUsesStableIdentity() {
        XCTAssertEqual(
            LibraryTrackListSource.allLibraryTracks.id,
            "library:all-tracks"
        )
    }

    func testCollectionValueIdentityChangesBetweenValues() {
        let first = LibraryTrackListSource.collectionValue(
            category: .artists,
            rawValue: "Artist A",
            artistKey: nil
        )
        let second = LibraryTrackListSource.collectionValue(
            category: .artists,
            rawValue: "Artist B",
            artistKey: nil
        )

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.id, first.id)
    }
}

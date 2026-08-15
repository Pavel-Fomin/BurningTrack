//
//  NewTrackListSelectionFolderPresenterTests.swift
//  TrackListTests
//
//  Проверяет presentation-состояние папки выбора треков.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class NewTrackListSelectionFolderPresenterTests: XCTestCase {
    func testPresenterPublishesAllVisibleTracksSelectedWithoutViewModelQuery() {
        let trackA = makeTrack(name: "A.mp3")
        let trackB = makeTrack(name: "B.mp3")
        var tracksState = LibraryTracksScreenState(sortMode: .titleAsc)
        tracksState.sections = [
            TrackSection(id: "flat", header: .hidden, tracks: [trackA, trackB])
        ]

        let state = NewTrackListSelectionFolderPresenter().makeState(
            tracksState: tracksState,
            selectableSections: [],
            selectedTrackIDs: [trackA.id, trackB.id]
        )

        XCTAssertTrue(state.hasVisibleTracks)
        XCTAssertTrue(state.areAllVisibleTracksSelected)
    }

    func testSelectableRowStatePreservesSelectionFavoriteAvailabilityAndFileFormat() {
        let track = makeTrack(name: "Unavailable.flac", isAvailable: false)

        let row = TrackSelectableRowStateBuilder().build(
            track: track,
            snapshot: nil,
            favoriteTrackIds: [track.id],
            isSelected: true,
            showsFileFormat: true
        )

        XCTAssertTrue(row.isSelected)
        XCTAssertEqual(row.artworkBadgeState, .favorite)
        XCTAssertFalse(row.track.isAvailable)
        XCTAssertTrue(row.showsFileFormat)
    }

    private func makeTrack(
        name: String,
        isAvailable: Bool = true
    ) -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/\(name)"),
            title: name,
            artist: "Artist",
            duration: 180,
            addedDate: Date(),
            isAvailable: isAvailable
        )
    }
}

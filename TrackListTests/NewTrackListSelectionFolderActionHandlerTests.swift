//
//  NewTrackListSelectionFolderActionHandlerTests.swift
//  TrackListTests
//
//  Проверяет typed ingress папки выбора треков в Library Tracks.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class NewTrackListSelectionFolderActionHandlerTests: XCTestCase {
    func testScreenAppearedUsesCanonicalLibraryTracksLifecycleAction() {
        let libraryTracks = NewTrackListSelectionFolderLibraryTracksSpy()
        let handler = NewTrackListSelectionFolderActionHandler(
            libraryTracks: libraryTracks
        )

        handler.handle(.screenAppeared)

        XCTAssertEqual(libraryTracks.actions.count, 1)
        guard case .screenAppeared? = libraryTracks.actions.first else {
            return XCTFail("Должно быть отправлено действие initial load")
        }
    }

    func testSnapshotRequestUsesTypedFolderActionInsteadOfViewModelCallFromView() {
        let libraryTracks = NewTrackListSelectionFolderLibraryTracksSpy()
        let handler = NewTrackListSelectionFolderActionHandler(
            libraryTracks: libraryTracks
        )
        let trackID = UUID()

        handler.handle(.snapshotRequested(trackID))

        XCTAssertEqual(libraryTracks.snapshotRequestIDs, [trackID])
    }
}

/// Фиксирует обращения folder handler-а без создания production Library Tracks graph.
@MainActor
private final class NewTrackListSelectionFolderLibraryTracksSpy: NewTrackListSelectionFolderLibraryTracksHandling {
    private(set) var actions: [LibraryTracksAction] = []
    private(set) var snapshotRequestIDs: [UUID] = []

    func send(_ action: LibraryTracksAction) {
        actions.append(action)
    }

    func requestSnapshotIfNeeded(for trackID: UUID) {
        snapshotRequestIDs.append(trackID)
    }
}

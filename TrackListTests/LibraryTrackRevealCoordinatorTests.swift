//
//  LibraryTrackRevealCoordinatorTests.swift
//  TrackListTests
//
//  Проверяет ownership reveal request и lifecycle подсветки фонотеки.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class LibraryTrackRevealCoordinatorTests: XCTestCase {

    func testPendingRevealHasPriorityOverActiveTrackScroll() {
        let targetTrackId = UUID()
        let revealRequest = makeRevealRequest(
            targetTrackId: targetTrackId
        )
        let coordinator = LibraryTrackRevealCoordinator(
            initialRequest: revealRequest
        )

        let activeRequest = coordinator.activeTrackScrollRequestIfNeeded(
            currentDisplayableId: targetTrackId,
            currentContext: .library,
            trackSections: sections(containing: targetTrackId)
        )

        XCTAssertNil(activeRequest)
    }

    func testNewRevealInvalidatesOlderCandidateBeforeScroll() {
        let firstTrackId = UUID()
        let secondTrackId = UUID()
        let firstRequest = makeRevealRequest(targetTrackId: firstTrackId)
        let secondRequest = makeRevealRequest(targetTrackId: secondTrackId)
        let coordinator = LibraryTrackRevealCoordinator(initialRequest: nil)

        let firstDecision = coordinator.receiveRevealRequest(
            firstRequest,
            trackSections: sections(containing: firstTrackId),
            didLoad: true,
            isLoading: false
        )
        let secondDecision = coordinator.receiveRevealRequest(
            secondRequest,
            trackSections: sections(containing: secondTrackId),
            didLoad: true,
            isLoading: false
        )

        guard case .reveal(let firstCandidate) = firstDecision,
              case .reveal(let secondCandidate) = secondDecision else {
            return XCTFail("Reveal requests should produce scroll candidates")
        }

        XCTAssertNil(coordinator.prepareRevealScrollIfCurrent(firstCandidate))
        XCTAssertEqual(
            coordinator.prepareRevealScrollIfCurrent(secondCandidate),
            secondCandidate
        )
    }

    func testStaleHighlightCompletionCannotClearNewRevealHighlight() {
        let firstTrackId = UUID()
        let secondTrackId = UUID()
        let firstRequest = makeRevealRequest(targetTrackId: firstTrackId)
        let secondRequest = makeRevealRequest(targetTrackId: secondTrackId)
        let coordinator = LibraryTrackRevealCoordinator(initialRequest: nil)

        let firstCandidate = revealCandidate(
            from: coordinator.receiveRevealRequest(
                firstRequest,
                trackSections: sections(containing: firstTrackId),
                didLoad: true,
                isLoading: false
            )
        )
        XCTAssertEqual(
            coordinator.prepareRevealScrollIfCurrent(firstCandidate),
            firstCandidate
        )
        XCTAssertEqual(
            coordinator.markRevealScrollPerformed(firstCandidate),
            firstRequest.requestId
        )

        let secondCandidate = revealCandidate(
            from: coordinator.receiveRevealRequest(
                secondRequest,
                trackSections: sections(containing: secondTrackId),
                didLoad: true,
                isLoading: false
            )
        )
        XCTAssertEqual(
            coordinator.prepareRevealScrollIfCurrent(secondCandidate),
            secondCandidate
        )
        XCTAssertEqual(
            coordinator.markRevealScrollPerformed(secondCandidate),
            secondRequest.requestId
        )

        coordinator.clearRevealHighlightIfCurrent(firstCandidate)

        XCTAssertEqual(coordinator.revealedTrackID, secondTrackId)
    }

    func testMissingTargetCompletesRevealWithoutScroll() {
        let request = makeRevealRequest(targetTrackId: UUID())
        let coordinator = LibraryTrackRevealCoordinator(initialRequest: nil)

        let decision = coordinator.receiveRevealRequest(
            request,
            trackSections: [],
            didLoad: true,
            isLoading: false
        )

        XCTAssertEqual(decision, .complete(requestId: request.requestId))
    }

    private func makeRevealRequest(
        targetTrackId: UUID
    ) -> LibraryRevealRequest {
        LibraryRevealRequest(
            destination: .folder(UUID()),
            targetTrackId: targetTrackId,
            requestId: UUID()
        )
    }

    private func revealCandidate(
        from decision: LibraryTrackRevealDecision
    ) -> LibraryTrackRevealScrollRequest {
        guard case .reveal(let request) = decision else {
            XCTFail("Reveal request should produce a scroll candidate")
            return LibraryTrackRevealScrollRequest(
                trackId: UUID(),
                requestId: UUID()
            )
        }

        return request
    }

    private func sections(
        containing trackId: UUID
    ) -> [TrackSection] {
        let track = LibraryTrack(
            id: trackId,
            fileURL: URL(fileURLWithPath: "/tmp/track.mp3"),
            title: "Track",
            artist: "Artist",
            duration: 1,
            addedDate: .now
        )

        return [
            TrackSection(
                id: "section",
                header: .hidden,
                tracks: [track]
            )
        ]
    }
}

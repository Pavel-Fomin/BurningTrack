//
//  AutomaticListScrollCoordinatorTests.swift
//  TrackListTests
//
//  Проверяет UI-политику автоматической прокрутки без ScrollViewProxy.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class AutomaticListScrollCoordinatorTests: XCTestCase {

    func testRevealSupersedesPendingAutomaticScroll() {
        let coordinator = AutomaticListScrollCoordinator()
        let activeTrackId = UUID()

        let automaticRequest = coordinator.requestActiveTrackScrollIfNeeded(
            targetId: activeTrackId,
            isTargetAvailable: true
        )

        XCTAssertNotNil(automaticRequest)
        XCTAssertTrue(coordinator.beginRevealScroll())
        XCTAssertNil(coordinator.pendingScrollRequest)
        XCTAssertEqual(coordinator.state, .programmatic)
    }

    func testSecondAutomaticRequestWaitsForAcceptedProgrammaticScroll() {
        let coordinator = AutomaticListScrollCoordinator()
        let firstTrackId = UUID()
        let secondTrackId = UUID()

        let firstRequest = coordinator.requestActiveTrackScrollIfNeeded(
            targetId: firstTrackId,
            isTargetAvailable: true
        )
        XCTAssertNotNil(firstRequest)
        XCTAssertTrue(coordinator.beginScroll(firstRequest!))

        let secondRequest = coordinator.requestActiveTrackScrollIfNeeded(
            targetId: secondTrackId,
            isTargetAvailable: true
        )

        XCTAssertNil(secondRequest)
        XCTAssertEqual(coordinator.state, .programmatic)
    }

    func testNaturalTransitionAfterManualPositionStaysSuppressed() {
        let coordinator = AutomaticListScrollCoordinator()

        coordinator.receiveScrollPhase(.userInteraction)
        coordinator.receiveScrollPhase(.idle)

        let request = coordinator.requestActiveTrackScrollIfNeeded(
            targetId: UUID(),
            isTargetAvailable: true
        )

        XCTAssertEqual(coordinator.userPosition, .manuallyPositioned)
        XCTAssertNil(request)
    }

    func testInitialAppearancePermitsAvailableActiveTrack() {
        let coordinator = AutomaticListScrollCoordinator()
        let activeTrackId = UUID()

        let request = coordinator.requestInitialScrollIfNeeded(
            targetId: activeTrackId,
            isTargetAvailable: true
        )

        XCTAssertEqual(request?.targetId, activeTrackId)
        XCTAssertEqual(request?.isAnimated, false)
    }

    func testIdlePhaseDoesNotDiscardAutomaticRequestBeforeViewPerformsIt() {
        let coordinator = AutomaticListScrollCoordinator()
        let request = coordinator.requestActiveTrackScrollIfNeeded(
            targetId: UUID(),
            isTargetAvailable: true
        )

        coordinator.receiveScrollPhase(.idle)

        XCTAssertEqual(coordinator.pendingScrollRequest, request)
    }

    func testUserInteractionCancelsUnmaterializedAutomaticRequest() {
        let coordinator = AutomaticListScrollCoordinator()
        let request = coordinator.requestActiveTrackScrollIfNeeded(
            targetId: UUID(),
            isTargetAvailable: true
        )

        coordinator.receiveScrollPhase(.userInteraction)

        XCTAssertNotNil(request)
        XCTAssertNil(coordinator.pendingScrollRequest)
        XCTAssertEqual(coordinator.state, .userInteracting)
    }

    func testExplicitRevealRemainsAvailableAfterManualScrollEnds() {
        let coordinator = AutomaticListScrollCoordinator()

        coordinator.receiveScrollPhase(.userInteraction)
        coordinator.receiveScrollPhase(.idle)

        XCTAssertTrue(coordinator.beginRevealScroll())
    }

    func testMissingTargetDoesNotCreateAutomaticRequest() {
        let coordinator = AutomaticListScrollCoordinator()

        let request = coordinator.requestActiveTrackScrollIfNeeded(
            targetId: UUID(),
            isTargetAvailable: false
        )

        XCTAssertNil(request)
        XCTAssertEqual(coordinator.state, .idle)
    }

    func testNextNavigationAfterManualPositionCreatesExplicitRequest() {
        let coordinator = AutomaticListScrollCoordinator()
        let nextTrackId = UUID()
        let triggerId = UUID()

        coordinator.receiveScrollPhase(.userInteraction)
        coordinator.receiveScrollPhase(.idle)

        let request = coordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
            triggerId: triggerId,
            targetId: nextTrackId,
            isTargetAvailable: true
        )

        XCTAssertEqual(request?.targetId, nextTrackId)
        XCTAssertEqual(
            request?.kind,
            .explicitPlaybackNavigation(triggerId: triggerId)
        )
    }

    func testPreviousNavigationAfterManualPositionCreatesExplicitRequest() {
        let coordinator = AutomaticListScrollCoordinator()
        let previousTrackId = UUID()
        let triggerId = UUID()

        coordinator.receiveScrollPhase(.userInteraction)
        coordinator.receiveScrollPhase(.idle)

        let request = coordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
            triggerId: triggerId,
            targetId: previousTrackId,
            isTargetAvailable: true
        )

        XCTAssertEqual(request?.targetId, previousTrackId)
        XCTAssertEqual(coordinator.pendingScrollRequest, request)
    }

    func testNavigationDuringDragDefersUntilIdle() {
        let coordinator = AutomaticListScrollCoordinator()
        let targetId = UUID()

        coordinator.receiveScrollPhase(.userInteraction)

        let request = coordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
            triggerId: UUID(),
            targetId: targetId,
            isTargetAvailable: true
        )

        XCTAssertNil(request)
        XCTAssertNil(coordinator.pendingScrollRequest)

        let deferredRequest = coordinator.receiveScrollPhase(.idle)

        XCTAssertEqual(coordinator.pendingScrollRequest?.targetId, targetId)
        XCTAssertEqual(deferredRequest?.targetId, targetId)
    }

    func testMultipleNavigationRequestsDuringDragKeepOnlyLatestTarget() {
        let coordinator = AutomaticListScrollCoordinator()
        let firstTargetId = UUID()
        let latestTargetId = UUID()

        coordinator.receiveScrollPhase(.userInteraction)
        _ = coordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
            triggerId: UUID(),
            targetId: firstTargetId,
            isTargetAvailable: true
        )
        _ = coordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
            triggerId: UUID(),
            targetId: latestTargetId,
            isTargetAvailable: true
        )

        let deferredRequest = coordinator.receiveScrollPhase(.idle)

        XCTAssertEqual(coordinator.pendingScrollRequest?.targetId, latestTargetId)
        XCTAssertEqual(deferredRequest?.targetId, latestTargetId)
    }

    func testRevealPriorityDiscardsDeferredPlaybackNavigation() {
        let coordinator = AutomaticListScrollCoordinator()

        coordinator.receiveScrollPhase(.userInteraction)
        _ = coordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
            triggerId: UUID(),
            targetId: UUID(),
            isTargetAvailable: true
        )

        coordinator.discardExplicitPlaybackNavigationForReveal()
        coordinator.receiveScrollPhase(.idle)

        XCTAssertNil(coordinator.pendingScrollRequest)
        XCTAssertTrue(coordinator.beginRevealScroll())
    }

    func testMissingTargetDoesNotCreateExplicitNavigationRequest() {
        let coordinator = AutomaticListScrollCoordinator()

        let request = coordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
            triggerId: UUID(),
            targetId: UUID(),
            isTargetAvailable: false
        )

        XCTAssertNil(request)
        XCTAssertNil(coordinator.pendingScrollRequest)
    }
}

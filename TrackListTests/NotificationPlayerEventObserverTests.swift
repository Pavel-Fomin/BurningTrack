//
//  NotificationPlayerEventObserverTests.swift
//  TrackList
//
//  Проверяет MainActor-ownership и перевод событий NotificationCenter в Player callbacks.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class NotificationPlayerEventObserverTests: XCTestCase {

    func testDurationEventDeliversExactValue() async {
        let notificationCenter = NotificationCenter()
        let observer = NotificationPlayerEventObserver(
            notificationCenter: notificationCenter
        )
        let expectedDuration: TimeInterval = 245.5
        var receivedDurations: [TimeInterval] = []
        let expectation = expectation(description: "Duration callback")

        observer.onTrackDurationUpdated = { duration in
            receivedDurations.append(duration)
            expectation.fulfill()
        }

        notificationCenter.post(
            name: .trackDurationUpdated,
            object: nil,
            userInfo: ["duration": expectedDuration]
        )

        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(receivedDurations, [expectedDuration])
    }

    func testInvalidDurationEventIsIgnored() {
        let notificationCenter = NotificationCenter()
        let observer = NotificationPlayerEventObserver(
            notificationCenter: notificationCenter
        )
        var callbackCount = 0

        observer.onTrackDurationUpdated = { _ in
            callbackCount += 1
        }

        notificationCenter.post(
            name: .trackDurationUpdated,
            object: nil,
            userInfo: ["duration": "invalid"]
        )

        XCTAssertEqual(callbackCount, 0)
    }

    func testFinishEventIsDelivered() async {
        let notificationCenter = NotificationCenter()
        let observer = NotificationPlayerEventObserver(
            notificationCenter: notificationCenter
        )
        var callbackCount = 0
        let expectation = expectation(description: "Finish callback")

        observer.onTrackDidFinish = {
            callbackCount += 1
            expectation.fulfill()
        }

        notificationCenter.post(name: .trackDidFinish, object: nil)

        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(callbackCount, 1)
    }

    func testTrackUpdateEventIsDelivered() async {
        let notificationCenter = NotificationCenter()
        let observer = NotificationPlayerEventObserver(
            notificationCenter: notificationCenter
        )
        let expectedEvent = makeTrackUpdateEvent()
        var receivedEvents: [TrackUpdateEvent] = []
        let expectation = expectation(description: "Track update callback")

        observer.onTrackDidUpdate = { event in
            receivedEvents.append(event)
            expectation.fulfill()
        }

        notificationCenter.post(name: .trackDidUpdate, object: expectedEvent)

        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(receivedEvents, [expectedEvent])
    }

    /// Одно batch-уведомление остаётся одним callback плеера даже при 300 подтверждённых snapshot.
    func testTrackBatchUpdateDeliversThreeHundredEventsInOneCallback() async {
        let notificationCenter = NotificationCenter()
        let observer = NotificationPlayerEventObserver(
            notificationCenter: notificationCenter
        )
        let expectedEvents = (0..<300).map { _ in makeTrackUpdateEvent() }
        var receivedBatches: [[TrackUpdateEvent]] = []
        let expectation = expectation(description: "Track batch update callback")

        observer.onTrackBatchDidUpdate = { events in
            receivedBatches.append(events)
            expectation.fulfill()
        }

        notificationCenter.post(
            name: .trackBatchDidUpdate,
            object: nil,
            userInfo: ["events": expectedEvents]
        )

        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(receivedBatches.count, 1)
        XCTAssertEqual(receivedBatches.first, expectedEvents)
    }

    func testInvalidTrackUpdateEventIsIgnored() {
        let notificationCenter = NotificationCenter()
        let observer = NotificationPlayerEventObserver(
            notificationCenter: notificationCenter
        )
        var callbackCount = 0

        observer.onTrackDidUpdate = { _ in
            callbackCount += 1
        }

        notificationCenter.post(name: .trackDidUpdate, object: "invalid")

        XCTAssertEqual(callbackCount, 0)
    }

    func testSettingsEventIsDelivered() async {
        let notificationCenter = NotificationCenter()
        let observer = NotificationPlayerEventObserver(
            notificationCenter: notificationCenter
        )
        var callbackCount = 0
        let expectation = expectation(description: "Settings callback")

        observer.onSettingsChanged = {
            callbackCount += 1
            expectation.fulfill()
        }

        notificationCenter.post(name: .appSettingsDidChange, object: nil)

        await fulfillment(of: [expectation], timeout: 1)

        XCTAssertEqual(callbackCount, 1)
    }

    func testObserverIsReleasedAndRemovesNotificationTokens() async {
        let notificationCenter = NotificationCenter()
        var callbackCount = 0
        weak var weakObserver: NotificationPlayerEventObserver?
        let expectation = expectation(description: "Initial finish callback")

        do {
            let observer = NotificationPlayerEventObserver(
                notificationCenter: notificationCenter
            )
            weakObserver = observer
            observer.onTrackDidFinish = {
                callbackCount += 1
                expectation.fulfill()
            }

            notificationCenter.post(name: .trackDidFinish, object: nil)

            await fulfillment(of: [expectation], timeout: 1)

            XCTAssertEqual(callbackCount, 1)
        }

        XCTAssertNil(weakObserver)

        notificationCenter.post(name: .trackDidFinish, object: nil)

        XCTAssertEqual(callbackCount, 1)
    }

    private func makeTrackUpdateEvent() -> TrackUpdateEvent {
        let trackId = UUID()

        return TrackUpdateEvent(
            trackId: trackId,
            reason: .metadataUpdated,
            changedFields: [.title],
            snapshot: TrackRuntimeSnapshot(
                trackId: trackId,
                fileName: "Observer.m4a",
                isAvailable: true,
                technicalMetadata: TrackTechnicalMetadata(
                    fileSizeBytes: nil,
                    fileFormat: "M4A",
                    bitrateBitsPerSecond: nil
                ),
                title: "Observer title",
                artist: nil,
                album: nil,
                albumArtist: nil,
                genre: nil,
                comment: nil,
                composer: nil,
                conductor: nil,
                lyricist: nil,
                remixer: nil,
                grouping: nil,
                bpm: nil,
                musicalKey: nil,
                trackNumber: nil,
                totalTracks: nil,
                discNumber: nil,
                totalDiscs: nil,
                year: nil,
                date: nil,
                publisherOrLabel: nil,
                copyright: nil,
                encodedBy: nil,
                isrc: nil,
                duration: nil,
                artworkData: nil,
                artworkSourceIdentifier: nil,
                updatedAt: Date(timeIntervalSince1970: 0)
            )
        )
    }
}

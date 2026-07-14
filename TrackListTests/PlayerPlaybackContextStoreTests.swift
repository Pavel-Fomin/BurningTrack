//
//  PlayerPlaybackContextStoreTests.swift
//  TrackListTests
//
//  Тесты восстановления и переключения контекста плеера.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class PlayerPlaybackContextStoreTests: XCTestCase {
    func testNextAndPreviousUseQueueItemIdentity() {
        let first = makePlayerTrack(trackId: UUID(), fileName: "first.mp3")
        let second = makePlayerTrack(trackId: UUID(), fileName: "second.mp3")
        let store = PlayerPlaybackContextStore()
        let queue: [any TrackDisplayable] = [first, second]

        _ = store.updateContext(currentTrack: first, context: queue)

        let next = store.nextTrack(after: first)
        XCTAssertEqual(next?.track.id, second.id)
        XCTAssertEqual(next?.track.trackId, second.trackId)

        let previous = store.previousTrack(before: second)
        XCTAssertEqual(previous?.track.id, first.id)
        XCTAssertEqual(previous?.track.trackId, first.trackId)
    }

    func testDuplicateTrackIdMovesBetweenQueueItems() {
        let sharedTrackId = UUID()
        let first = makePlayerTrack(trackId: sharedTrackId, fileName: "first-copy.mp3")
        let second = makePlayerTrack(trackId: sharedTrackId, fileName: "second-copy.mp3")
        let store = PlayerPlaybackContextStore()
        let queue: [any TrackDisplayable] = [first, second]

        _ = store.updateContext(currentTrack: first, context: queue)

        let next = store.nextTrack(after: first)
        XCTAssertEqual(next?.track.id, second.queueItemId)
        XCTAssertNotEqual(next?.track.id, first.queueItemId)

        let previous = store.previousTrack(before: second)
        XCTAssertEqual(previous?.track.id, first.queueItemId)
    }

    func testRestoredSecondQueueItemHasPreviousTrack() {
        let first = makePlayerTrack(trackId: UUID(), fileName: "first.mp3")
        let second = makePlayerTrack(trackId: UUID(), fileName: "second.mp3")
        let queue = [first, second]
        let restoredTrack = queue.first(where: { $0.queueItemId == second.queueItemId })
        let store = PlayerPlaybackContextStore()
        let context: [any TrackDisplayable] = queue

        XCTAssertEqual(restoredTrack?.queueItemId, second.queueItemId)
        guard let restoredTrack else {
            XCTFail("Не найден сохранённый элемент очереди")
            return
        }

        _ = store.updateContext(currentTrack: restoredTrack, context: context)

        let previous = store.previousTrack(before: restoredTrack)
        XCTAssertEqual(previous?.track.id, first.queueItemId)
    }

    /// Создаёт элементы очереди с разными queueItemId для проверки порядка.
    private func makePlayerTrack(trackId: UUID, fileName: String) -> PlayerTrack {
        PlayerTrack(
            queueItemId: UUID(),
            trackId: trackId,
            title: fileName,
            artist: nil,
            duration: 10,
            fileName: fileName,
            isAvailable: true
        )
    }
}

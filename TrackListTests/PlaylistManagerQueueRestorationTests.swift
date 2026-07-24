//
//  PlaylistManagerQueueRestorationTests.swift
//  TrackList
//
//  Проверки защиты очереди плеера от устаревшего восстановления.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class PlaylistManagerQueueRestorationTests: XCTestCase {

    func testFirstAddDuringRestorationIsNotReplacedByStaleQueue() {
        let persistedTrack = makeLibraryTrack(fileName: "Persisted.mp3")
        let addedTrack = makeLibraryTrack(fileName: "FirstAdded.mp3")
        let store = PlayerQueuePersistenceSpy(queue: [persistedTrack])
        let manager = PlaylistManager(databaseStore: store, loadsInitialQueue: false)

        store.onFetchQueue = {
            XCTAssertTrue(manager.addTracks([addedTrack]))
        }

        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertEqual(manager.tracks, [addedTrack])
        XCTAssertEqual(store.queue, [addedTrack])
    }

    func testLibraryAccessRestoredDoesNotReloadAfterSuccessfulFirstAdd() {
        let stalePersistedTrack = makeLibraryTrack(fileName: "Stale.mp3")
        let addedTrack = makeLibraryTrack(fileName: "FirstAdded.mp3")
        let store = PlayerQueuePersistenceSpy(queue: [stalePersistedTrack])
        let manager = PlaylistManager(databaseStore: store, loadsInitialQueue: false)

        XCTAssertTrue(manager.addTracks([addedTrack]))
        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertEqual(manager.tracks, [addedTrack])
        XCTAssertEqual(store.queue, [addedTrack])
        XCTAssertEqual(store.fetchQueueCallCount, 0)
    }

    func testStaleLoadDoesNotReplaceQueueChangedByUser() {
        let restoredTrack = makeLibraryTrack(fileName: "Restored.mp3")
        let addedTrack = makeLibraryTrack(fileName: "Added.mp3")
        let store = PlayerQueuePersistenceSpy(queue: [restoredTrack])
        let manager = PlaylistManager(databaseStore: store)

        store.onFetchQueue = {
            XCTAssertTrue(manager.addTracks([addedTrack]))
        }

        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertEqual(manager.tracks, [restoredTrack, addedTrack])
        XCTAssertEqual(store.queue, [restoredTrack, addedTrack])
    }

    func testRemovalDuringRestorationDoesNotReturnDeletedTrack() {
        let removedTrack = makeLibraryTrack(fileName: "Removed.mp3")
        let remainingTrack = makeLibraryTrack(fileName: "Remaining.mp3")
        let store = PlayerQueuePersistenceSpy(queue: [removedTrack, remainingTrack])
        let manager = PlaylistManager(databaseStore: store)

        store.onFetchQueue = {
            XCTAssertTrue(manager.remove(at: 0))
        }

        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertEqual(manager.tracks, [remainingTrack])
        XCTAssertEqual(store.queue, [remainingTrack])
    }

    func testMoveDuringRestorationKeepsUserOrder() {
        let firstTrack = makeLibraryTrack(fileName: "First.mp3")
        let secondTrack = makeLibraryTrack(fileName: "Second.mp3")
        let store = PlayerQueuePersistenceSpy(queue: [firstTrack, secondTrack])
        let manager = PlaylistManager(databaseStore: store)

        store.onFetchQueue = {
            manager.tracks.swapAt(0, 1)
            XCTAssertTrue(manager.saveQueue())
        }

        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertEqual(manager.tracks, [secondTrack, firstTrack])
        XCTAssertEqual(store.queue, [secondTrack, firstTrack])
    }

    func testUnavailablePersistedTrackRemainsInQueueAfterRestoration() {
        let unavailableTrack = makeLibraryTrack(
            fileName: "Unavailable.mp3",
            isAvailable: false
        )
        let store = PlayerQueuePersistenceSpy(queue: [unavailableTrack])
        let manager = PlaylistManager(databaseStore: store, loadsInitialQueue: false)

        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertEqual(manager.tracks, [unavailableTrack])
        XCTAssertFalse(manager.tracks[0].isAvailable)
        XCTAssertEqual(store.queue, [unavailableTrack])

        let restoredTrack = PlayerTrack(
            queueItemId: unavailableTrack.queueItemId,
            trackId: unavailableTrack.trackId,
            title: unavailableTrack.title,
            artist: unavailableTrack.artist,
            album: unavailableTrack.album,
            artworkData: unavailableTrack.artworkData,
            duration: unavailableTrack.duration,
            fileName: unavailableTrack.fileName,
            isAvailable: true,
            source: unavailableTrack.source,
            assetURL: unavailableTrack.assetURL
        )
        store.queue = [restoredTrack]

        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertEqual(manager.tracks, [restoredTrack])
        XCTAssertTrue(manager.tracks[0].isAvailable)
    }

    func testPurchasedITunesTrackSurvivesLibraryAccessRestoration() throws {
        let assetURL = try XCTUnwrap(URL(string: "ipod-library://item/item.m4a?id=1001"))
        let purchasedTrack = PlayerTrack(
            trackId: UUID(),
            title: "Purchased",
            artist: "Artist",
            duration: 30,
            fileName: "Purchased",
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: assetURL
        )
        let store = PlayerQueuePersistenceSpy(queue: [purchasedTrack])
        let manager = PlaylistManager(databaseStore: store, loadsInitialQueue: false)

        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertEqual(manager.tracks, [purchasedTrack])
        XCTAssertEqual(manager.tracks[0].source, .purchasedITunes)
        XCTAssertEqual(manager.tracks[0].assetURL, assetURL)
    }

    func testMixedQueueKeepsOrderAndQueueItemIdentifiersAfterRestoration() throws {
        let firstLibraryTrack = makeLibraryTrack(fileName: "First.mp3")
        let assetURL = try XCTUnwrap(URL(string: "ipod-library://item/item.m4a?id=1002"))
        let purchasedTrack = PlayerTrack(
            trackId: UUID(),
            title: "Purchased",
            artist: nil,
            duration: 30,
            fileName: "Purchased",
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: assetURL
        )
        let secondLibraryTrack = makeLibraryTrack(fileName: "Second.mp3")
        let expectedQueue = [firstLibraryTrack, purchasedTrack, secondLibraryTrack]
        let store = PlayerQueuePersistenceSpy(queue: expectedQueue)
        let manager = PlaylistManager(databaseStore: store, loadsInitialQueue: false)

        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertEqual(manager.tracks, expectedQueue)
        XCTAssertEqual(manager.tracks.map(\.queueItemId), expectedQueue.map(\.queueItemId))
    }

    func testExplicitClearDuringRestorationPreventsOldQueueFromReturning() {
        let restoredTrack = makeLibraryTrack(fileName: "Restored.mp3")
        let store = PlayerQueuePersistenceSpy(queue: [restoredTrack])
        let manager = PlaylistManager(databaseStore: store)

        store.onFetchQueue = {
            XCTAssertTrue(manager.clear())
        }

        manager.reloadQueueAfterLibraryAccessRestored()

        XCTAssertTrue(manager.tracks.isEmpty)
        XCTAssertTrue(store.queue.isEmpty)
    }

    /// Создаёт локальный snapshot очереди без обращения к файловой системе.
    private func makeLibraryTrack(
        fileName: String,
        isAvailable: Bool = true
    ) -> PlayerTrack {
        PlayerTrack(
            trackId: UUID(),
            title: fileName,
            artist: nil,
            duration: 30,
            fileName: fileName,
            isAvailable: isAvailable
        )
    }
}

/// Имитирует PlayerDatabaseStore и позволяет завершить чтение устаревшим снимком после пользовательской мутации.
private final class PlayerQueuePersistenceSpy: PlayerQueuePersisting {
    var queue: [PlayerTrack]
    var onFetchQueue: (() -> Void)?
    private(set) var fetchQueueCallCount = 0

    init(queue: [PlayerTrack]) {
        self.queue = queue
    }

    func fetchQueue() throws -> [PlayerTrack] {
        fetchQueueCallCount += 1
        let snapshot = queue
        let action = onFetchQueue
        onFetchQueue = nil
        action?()
        return snapshot
    }

    func replaceQueue(_ tracks: [PlayerTrack]) throws {
        queue = tracks
    }
}

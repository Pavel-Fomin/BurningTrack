//
//  FavoritesServiceTests.swift
//  TrackListTests
//
//  Проверки доменного сервиса системного треклиста «Избранное».
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Combine
import XCTest
@testable import TrackList

final class FavoritesServiceTests: XCTestCase {

    private var database: AppDatabase?
    private var databaseDirectory: URL?

    override func tearDownWithError() throws {
        // Закрываем временную базу перед удалением файлов WAL и SHM.
        try database?.close()
        database = nil

        if let databaseDirectory {
            try? FileManager.default.removeItem(at: databaseDirectory)
        }
        databaseDirectory = nil

        try super.tearDownWithError()
    }

    @MainActor
    func testAddUsesExistingFavoritesWithoutEnsure() throws {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: FavoritesEventsRecorder()
        )

        let result = try service.add(makeInput())

        XCTAssertEqual(result, .added)
        XCTAssertEqual(managers.trackLists.ensureCalls, 0)
        XCTAssertEqual(managers.trackList.tracks(for: favorites.id).count, 1)
    }

    @MainActor
    func testMissingFavoritesAreEnsuredBeforeReadingState() throws {
        let managers = makeManagers(favorites: nil)
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: FavoritesEventsRecorder()
        )

        XCTAssertFalse(try service.isFavorite(trackId: UUID()))

        let favorites = try XCTUnwrap(managers.trackLists.currentFavorites)
        XCTAssertEqual(favorites.kind, .favorites)
        XCTAssertEqual(managers.trackLists.ensureCalls, 1)
        XCTAssertEqual(managers.trackList.tracks(for: favorites.id), [])
    }

    @MainActor
    func testAddLocalTrackKeepsSnapshotAndDoesNotChangeRegularTrackList() throws {
        let favorites = makeFavoritesMeta()
        let regular = TrackListMeta(
            id: UUID(),
            name: "Regular",
            createdAt: Date(),
            kind: .regular
        )
        let regularTrackId = UUID()
        let regularTracks = [
            makeTrack(trackId: regularTrackId, title: "Regular one"),
            makeTrack(trackId: regularTrackId, title: "Regular two")
        ]
        let managers = makeManagers(
            favorites: favorites,
            tracksByListId: [regular.id: regularTracks]
        )
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: FavoritesEventsRecorder()
        )
        let input = makeInput(
            title: "Local title",
            artist: "Local artist",
            album: "Local album",
            artworkData: Data([1, 2, 3]),
            duration: 201,
            fileName: "local.flac",
            isAvailable: false
        )

        let result = try service.add(input)
        let favoriteTrack = try XCTUnwrap(managers.trackList.tracks(for: favorites.id).first)

        XCTAssertEqual(result, .added)
        XCTAssertEqual(favoriteTrack.trackId, input.trackId)
        XCTAssertNotEqual(favoriteTrack.listItemId, input.trackId)
        XCTAssertEqual(favoriteTrack.title, input.title)
        XCTAssertEqual(favoriteTrack.artist, input.artist)
        XCTAssertEqual(favoriteTrack.album, input.album)
        XCTAssertEqual(favoriteTrack.artworkData, input.artworkData)
        XCTAssertEqual(favoriteTrack.duration, input.duration)
        XCTAssertEqual(favoriteTrack.fileName, input.fileName)
        XCTAssertEqual(favoriteTrack.isAvailable, input.isAvailable)
        XCTAssertEqual(managers.trackList.tracks(for: regular.id), regularTracks)
    }

    @MainActor
    func testRepeatedAddDoesNotCreateDuplicateOrChangeExistingListItem() throws {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: FavoritesEventsRecorder()
        )
        let input = makeInput()

        XCTAssertEqual(try service.add(input), .added)
        let firstListItemId = try XCTUnwrap(managers.trackList.tracks(for: favorites.id).first?.listItemId)
        XCTAssertEqual(try service.add(input), .unchanged(isFavorite: true))

        XCTAssertEqual(managers.trackList.tracks(for: favorites.id).count, 1)
        XCTAssertEqual(managers.trackList.tracks(for: favorites.id).first?.listItemId, firstListItemId)
        XCTAssertEqual(managers.trackList.saveCallCount, 1)
    }

    @MainActor
    func testRemoveDeletesAllOldDuplicatesOnlyFromFavorites() throws {
        let favorites = makeFavoritesMeta()
        let regular = TrackListMeta(
            id: UUID(),
            name: "Regular",
            createdAt: Date(),
            kind: .regular
        )
        let duplicatedTrackId = UUID()
        let untouchedTrackId = UUID()
        let managers = makeManagers(
            favorites: favorites,
            tracksByListId: [
                favorites.id: [
                    makeTrack(trackId: duplicatedTrackId, title: "Old first"),
                    makeTrack(trackId: untouchedTrackId, title: "Keep"),
                    makeTrack(trackId: duplicatedTrackId, title: "Old second")
                ],
                regular.id: [
                    makeTrack(trackId: duplicatedTrackId, title: "Regular first"),
                    makeTrack(trackId: duplicatedTrackId, title: "Regular second")
                ]
            ]
        )
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: FavoritesEventsRecorder()
        )

        XCTAssertTrue(try service.isFavorite(trackId: duplicatedTrackId))
        XCTAssertEqual(
            try service.add(makeInput(trackId: duplicatedTrackId)),
            .unchanged(isFavorite: true)
        )
        XCTAssertEqual(try service.remove(trackId: duplicatedTrackId), .removed)

        XCTAssertFalse(try service.isFavorite(trackId: duplicatedTrackId))
        XCTAssertEqual(managers.trackList.tracks(for: favorites.id).map(\.trackId), [untouchedTrackId])
        XCTAssertEqual(managers.trackList.tracks(for: regular.id).map(\.trackId), [duplicatedTrackId, duplicatedTrackId])
        XCTAssertEqual(try service.remove(trackId: duplicatedTrackId), .unchanged(isFavorite: false))
    }

    @MainActor
    func testToggleAndRemovalKeepExistingOrder() throws {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: FavoritesEventsRecorder()
        )
        let first = makeInput()
        let second = makeInput()
        let third = makeInput()

        XCTAssertEqual(try service.add(first), .added)
        XCTAssertEqual(try service.toggle(second), .added)
        XCTAssertEqual(try service.add(third), .added)
        XCTAssertEqual(try service.toggle(second), .removed)

        XCTAssertEqual(managers.trackList.tracks(for: favorites.id).map(\.trackId), [first.trackId, third.trackId])
        XCTAssertEqual(try service.isFavorite(trackId: first.trackId), true)
        XCTAssertEqual(try service.isFavorite(trackId: second.trackId), false)
        XCTAssertTrue((try service.toggle(first)).didChange)
        XCTAssertFalse((try service.isFavorite(trackId: first.trackId)))
    }

    @MainActor
    func testLocalTrackIdentitySurvivesSnapshotChangesAndTemporaryUnavailability() throws {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: FavoritesEventsRecorder()
        )
        let trackId = UUID()
        let original = LibraryTrack(
            id: trackId,
            fileURL: URL(fileURLWithPath: "/Music/Before.mp3"),
            title: "Before",
            artist: "Artist",
            duration: 60,
            addedDate: Date(),
            isAvailable: true
        )
        let renamedAndUnavailable = LibraryTrack(
            id: trackId,
            fileURL: URL(fileURLWithPath: "/Music/Moved/After.mp3"),
            title: "After",
            artist: "Changed artist",
            duration: 61,
            addedDate: Date(),
            isAvailable: false
        )

        XCTAssertEqual(try service.add(FavoriteTrackInput(libraryTrack: original)), .added)
        XCTAssertEqual(FavoriteTrackInput(libraryTrack: renamedAndUnavailable).trackId, trackId)
        XCTAssertTrue(try service.isFavorite(trackId: renamedAndUnavailable.id))
        XCTAssertEqual(managers.trackList.tracks(for: favorites.id).first?.fileName, "Before.mp3")
    }

    @MainActor
    func testPurchasedITunesInputUsesExternalIdentityAndDoesNotMatchLocalCopy() throws {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: FavoritesEventsRecorder()
        )
        let source = PurchasedITunesTrack(
            id: 9001,
            title: "Purchased",
            artist: "Artist",
            album: "Album",
            year: 2026,
            genre: "Genre",
            dateAdded: Date(),
            artworkData: Data([9]),
            duration: 180,
            assetURL: try XCTUnwrap(URL(string: "ipod-library://item/item.m4a?id=9001"))
        )
        let iTunesTrack = PurchasedITunesPlayableTrack(track: source)
        let iTunesInput = FavoriteTrackInput(purchasedITunesTrack: iTunesTrack)
        let localCopy = makeInput(
            trackId: UUID(),
            title: iTunesTrack.title,
            artist: iTunesTrack.artist,
            fileName: iTunesTrack.fileName
        )

        XCTAssertEqual(try service.add(iTunesInput), .added)
        XCTAssertEqual(try service.add(iTunesInput), .unchanged(isFavorite: true))
        XCTAssertTrue(try service.isFavorite(trackId: iTunesTrack.trackId))
        let anotherITunesTrackId = UUID.v5(from: "purchased-itunes:9002")
        XCTAssertNotEqual(anotherITunesTrackId, iTunesTrack.trackId)
        XCTAssertFalse(try service.isFavorite(trackId: anotherITunesTrackId))
        XCTAssertFalse(try service.isFavorite(trackId: localCopy.trackId))
        XCTAssertEqual(managers.trackList.tracks(for: favorites.id).first?.source, .purchasedITunes)
        XCTAssertEqual(managers.trackList.tracks(for: favorites.id).first?.assetURL, iTunesTrack.assetURL)
        XCTAssertEqual(try service.remove(trackId: iTunesTrack.trackId), .removed)
    }

    @MainActor
    func testConcurrentAddsAreSerializedOnMainActor() async throws {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: FavoritesEventsRecorder()
        )
        let input = makeInput()
        let first = Task { @MainActor in
            try service.add(input)
        }
        let second = Task { @MainActor in
            try service.add(input)
        }

        let firstResult = try await first.value
        let secondResult = try await second.value
        let results = [firstResult, secondResult]

        XCTAssertTrue(results.contains(.added))
        XCTAssertTrue(results.contains(.unchanged(isFavorite: true)))
        XCTAssertEqual(managers.trackList.tracks(for: favorites.id).count, 1)
    }

    @MainActor
    func testFavoritesPersistAcrossReloadAndDoNotChangeLibraryQueueOrRegularDuplicates() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackListStore = TrackListDatabaseStore(executor: executor)
        let libraryTrackStore = SQLiteTrackStore(executor: executor)
        let playerStore = PlayerDatabaseStore(
            queueStore: SQLitePlayerQueueStore(executor: executor),
            stateStore: SQLitePlayerStateStore(executor: executor)
        )
        let localTrackId = UUID()
        let regularTrack = makeTrack(trackId: localTrackId, title: "Regular duplicate")
        let regular = try trackListStore.createTrackList(
            id: UUID(),
            name: "Regular",
            kind: .regular,
            createdAt: Date(),
            tracks: [regularTrack, makeTrack(trackId: localTrackId, title: "Regular duplicate")]
        )
        try libraryTrackStore.insert(
            TrackDatabaseModel(
                id: localTrackId,
                source: .library,
                folderId: nil,
                rootFolderId: nil,
                fileName: "Local.mp3",
                relativePath: "Local.mp3",
                fileExtension: "mp3",
                fileSize: nil,
                fileDate: Date(),
                importedAt: Date(),
                updatedAt: Date(),
                bookmarkBase64: nil,
                assetURLString: nil,
                isAvailable: true,
                isDeleted: false
            )
        )
        try playerStore.replaceQueue([
            PlayerTrack(
                trackId: localTrackId,
                title: "Local",
                artist: "Artist",
                duration: 120,
                fileName: "Local.mp3",
                isAvailable: true
            )
        ])

        let eventsRecorder = FavoritesEventsRecorder()
        let firstService = FavoritesService(
            trackListsManager: TrackListsManager(databaseStore: trackListStore),
            trackListManager: TrackListManager(databaseStore: trackListStore),
            favoritesEvents: eventsRecorder
        )
        let localInput = makeInput(
            trackId: localTrackId,
            title: "Local",
            artist: "Artist",
            fileName: "Local.mp3"
        )
        let iTunesInput = makeInput(
            trackId: UUID.v5(from: "purchased-itunes:7001"),
            title: "Purchased",
            artist: "Artist",
            album: "Album",
            duration: 200,
            fileName: "Purchased",
            source: .purchasedITunes,
            assetURL: try XCTUnwrap(URL(string: "ipod-library://item/item.m4a?id=7001"))
        )

        XCTAssertEqual(try firstService.add(localInput), .added)
        XCTAssertEqual(try firstService.add(iTunesInput), .added)
        XCTAssertEqual(
            eventsRecorder.events,
            [
                FavoritesChangeEvent(trackId: localTrackId, isFavorite: true),
                FavoritesChangeEvent(trackId: iTunesInput.trackId, isFavorite: true)
            ]
        )
        let favorites = try XCTUnwrap(try TrackListsManager(databaseStore: trackListStore).favoritesTrackList())
        let savedTracks = try trackListStore.fetchTracks(for: favorites.id)
        XCTAssertEqual(savedTracks.map(\.trackId), [localTrackId, iTunesInput.trackId])
        XCTAssertEqual(savedTracks.last?.source, .purchasedITunes)
        XCTAssertEqual(savedTracks.last?.assetURL, iTunesInput.assetURL)

        try closeDatabaseForReload()
        let reopenedDatabase = try reopenDatabase()
        let reopenedStore = TrackListDatabaseStore(executor: try reopenedDatabase.databaseExecutor())
        let reopenedService = FavoritesService(
            trackListsManager: TrackListsManager(databaseStore: reopenedStore),
            trackListManager: TrackListManager(databaseStore: reopenedStore),
            favoritesEvents: eventsRecorder
        )

        let eventsCountBeforeRead = eventsRecorder.events.count
        XCTAssertTrue(try reopenedService.isFavorite(trackId: localTrackId))
        XCTAssertTrue(try reopenedService.isFavorite(trackId: iTunesInput.trackId))
        XCTAssertEqual(eventsRecorder.events.count, eventsCountBeforeRead)
        XCTAssertEqual(try reopenedService.remove(trackId: localTrackId), .removed)
        XCTAssertEqual(
            eventsRecorder.events.last,
            FavoritesChangeEvent(trackId: localTrackId, isFavorite: false)
        )
        XCTAssertEqual(try reopenedStore.fetchTracks(for: regular.id).map(\.trackId), [localTrackId, localTrackId])
        XCTAssertNotNil(try LibraryDatabaseStore(executor: try reopenedDatabase.databaseExecutor()).fetchTrack(id: localTrackId))
        XCTAssertEqual(try PlayerDatabaseStore(
            queueStore: SQLitePlayerQueueStore(executor: try reopenedDatabase.databaseExecutor()),
            stateStore: SQLitePlayerStateStore(executor: try reopenedDatabase.databaseExecutor())
        ).fetchQueue().map(\.trackId), [localTrackId])

        try closeDatabaseForReload()
        let finalDatabase = try reopenDatabase()
        let finalStore = TrackListDatabaseStore(executor: try finalDatabase.databaseExecutor())
        let finalService = FavoritesService(
            trackListsManager: TrackListsManager(databaseStore: finalStore),
            trackListManager: TrackListManager(databaseStore: finalStore),
            favoritesEvents: eventsRecorder
        )

        let eventsCountBeforeFinalRead = eventsRecorder.events.count
        XCTAssertFalse(try finalService.isFavorite(trackId: localTrackId))
        XCTAssertTrue(try finalService.isFavorite(trackId: iTunesInput.trackId))
        XCTAssertFalse(try finalService.isFavorite(trackId: UUID()))
        XCTAssertEqual(eventsRecorder.events.count, eventsCountBeforeFinalRead)
    }

    @MainActor
    func testFavoritesServicePublishesOnlySuccessfulAddAndRemoveChanges() throws {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        let eventsRecorder = FavoritesEventsRecorder()
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: eventsRecorder
        )
        let input = makeInput()

        XCTAssertEqual(try service.add(input), .added)
        XCTAssertEqual(try service.add(input), .unchanged(isFavorite: true))
        XCTAssertEqual(try service.remove(trackId: input.trackId), .removed)
        XCTAssertEqual(try service.remove(trackId: input.trackId), .unchanged(isFavorite: false))

        XCTAssertEqual(
            eventsRecorder.events,
            [
                FavoritesChangeEvent(trackId: input.trackId, isFavorite: true),
                FavoritesChangeEvent(trackId: input.trackId, isFavorite: false)
            ]
        )
    }

    @MainActor
    func testTogglePublishesOneEventForEachFinalState() throws {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        let eventsRecorder = FavoritesEventsRecorder()
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: eventsRecorder
        )
        let input = makeInput()

        XCTAssertEqual(try service.toggle(input), .added)
        XCTAssertEqual(try service.toggle(input), .removed)

        XCTAssertEqual(
            eventsRecorder.events,
            [
                FavoritesChangeEvent(trackId: input.trackId, isFavorite: true),
                FavoritesChangeEvent(trackId: input.trackId, isFavorite: false)
            ]
        )
    }

    @MainActor
    func testRemovingOldDuplicatesPublishesOneLogicalEvent() throws {
        let favorites = makeFavoritesMeta()
        let duplicatedTrackId = UUID()
        let managers = makeManagers(
            favorites: favorites,
            tracksByListId: [
                favorites.id: [
                    makeTrack(trackId: duplicatedTrackId, title: "First"),
                    makeTrack(trackId: duplicatedTrackId, title: "Second")
                ]
            ]
        )
        let eventsRecorder = FavoritesEventsRecorder()
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: eventsRecorder
        )

        XCTAssertEqual(try service.remove(trackId: duplicatedTrackId), .removed)

        XCTAssertEqual(managers.trackList.tracks(for: favorites.id), [])
        XCTAssertEqual(
            eventsRecorder.events,
            [FavoritesChangeEvent(trackId: duplicatedTrackId, isFavorite: false)]
        )
    }

    @MainActor
    func testSaveFailureDoesNotPublishFavoritesEvent() {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        managers.trackList.allowsSaving = false
        let eventsRecorder = FavoritesEventsRecorder()
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: eventsRecorder
        )

        XCTAssertThrowsError(try service.add(makeInput())) { error in
            guard case AppError.trackListSaveFailed = error else {
                return XCTFail("Ожидалась ошибка сохранения треклиста")
            }
        }
        XCTAssertEqual(eventsRecorder.events, [])
    }

    @MainActor
    func testTwoTracksAndITunesTrackPublishTheirOwnStableIdentifiers() throws {
        let favorites = makeFavoritesMeta()
        let managers = makeManagers(favorites: favorites)
        let eventsRecorder = FavoritesEventsRecorder()
        let service = FavoritesService(
            trackListsManager: managers.trackLists,
            trackListManager: managers.trackList,
            favoritesEvents: eventsRecorder
        )
        let localA = makeInput()
        let localB = makeInput()
        let iTunesTrack = PurchasedITunesPlayableTrack(
            track: PurchasedITunesTrack(
                id: 8801,
                title: "Purchased",
                artist: "Artist",
                album: "Album",
                year: nil,
                genre: nil,
                dateAdded: Date(),
                artworkData: nil,
                duration: 180,
                assetURL: try XCTUnwrap(URL(string: "ipod-library://item/item.m4a?id=8801"))
            )
        )
        let iTunesInput = FavoriteTrackInput(purchasedITunesTrack: iTunesTrack)

        XCTAssertEqual(try service.add(localA), .added)
        XCTAssertEqual(try service.add(localB), .added)
        XCTAssertEqual(try service.add(iTunesInput), .added)
        XCTAssertEqual(try service.add(iTunesInput), .unchanged(isFavorite: true))
        XCTAssertEqual(try service.remove(trackId: localA.trackId), .removed)
        XCTAssertEqual(try service.remove(trackId: iTunesInput.trackId), .removed)

        XCTAssertEqual(
            eventsRecorder.events,
            [
                FavoritesChangeEvent(trackId: localA.trackId, isFavorite: true),
                FavoritesChangeEvent(trackId: localB.trackId, isFavorite: true),
                FavoritesChangeEvent(trackId: iTunesTrack.trackId, isFavorite: true),
                FavoritesChangeEvent(trackId: localA.trackId, isFavorite: false),
                FavoritesChangeEvent(trackId: iTunesTrack.trackId, isFavorite: false)
            ]
        )
    }

    @MainActor
    func testDirectFavoritesSavePublishesOnlyMembershipChanges() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let eventsRecorder = FavoritesEventsRecorder()
        let trackListsManager = TrackListsManager(databaseStore: store)
        let trackListManager = TrackListManager(
            databaseStore: store,
            favoritesEvents: eventsRecorder
        )
        let favorites = try trackListsManager.ensureFavoritesTrackList()
        let first = makeTrack(trackId: UUID(), title: "First")
        let second = makeTrack(trackId: UUID(), title: "Second")
        // Повторное вхождение того же трека имеет отдельный listItemId,
        // потому что каждая строка треклиста хранится как самостоятельный элемент.
        let secondDuplicate = Track(
            listItemId: UUID(),
            trackId: second.trackId,
            title: second.title,
            artist: second.artist,
            duration: second.duration,
            fileName: second.fileName,
            isAvailable: second.isAvailable
        )

        XCTAssertNoThrow(try trackListManager.saveTracks([first, second, secondDuplicate], for: favorites.id))
        XCTAssertEqual(
            eventsRecorder.events,
            [
                FavoritesChangeEvent(trackId: first.trackId, isFavorite: true),
                FavoritesChangeEvent(trackId: second.trackId, isFavorite: true)
            ]
        )

        eventsRecorder.removeAll()
        let changedSnapshot = Track(
            listItemId: first.listItemId,
            trackId: first.trackId,
            title: "Changed title",
            artist: first.artist,
            duration: first.duration,
            fileName: first.fileName,
            isAvailable: first.isAvailable
        )
        XCTAssertNoThrow(try trackListManager.saveTracks([second, changedSnapshot, secondDuplicate], for: favorites.id))
        XCTAssertEqual(eventsRecorder.events, [])

        XCTAssertNoThrow(try trackListManager.saveTracks([second], for: favorites.id))
        XCTAssertEqual(
            eventsRecorder.events,
            [FavoritesChangeEvent(trackId: first.trackId, isFavorite: false)]
        )

        let regular = try store.createTrackList(
            id: UUID(),
            name: "Regular",
            kind: .regular,
            createdAt: Date(),
            tracks: []
        )
        eventsRecorder.removeAll()
        XCTAssertNoThrow(try trackListManager.saveTracks([first], for: regular.id))
        XCTAssertEqual(eventsRecorder.events, [])
    }

    @MainActor
    func testFavoritesServiceDoesNotDuplicateTrackListManagerEvents() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let eventsRecorder = FavoritesEventsRecorder()
        let service = FavoritesService(
            trackListsManager: TrackListsManager(databaseStore: store),
            trackListManager: TrackListManager(
                databaseStore: store,
                favoritesEvents: eventsRecorder
            ),
            favoritesEvents: eventsRecorder
        )
        let input = makeInput()

        XCTAssertEqual(try service.add(input), .added)
        XCTAssertEqual(try service.toggle(input), .removed)
        XCTAssertEqual(
            eventsRecorder.events,
            [
                FavoritesChangeEvent(trackId: input.trackId, isFavorite: true),
                FavoritesChangeEvent(trackId: input.trackId, isFavorite: false)
            ]
        )
    }

    @MainActor
    func testFavoritesEventCenterDeliversTypedEventToSubscriber() {
        let notificationCenter = NotificationCenter()
        let eventCenter = FavoritesEventCenter(notificationCenter: notificationCenter)
        let expectedEvent = FavoritesChangeEvent(trackId: UUID(), isFavorite: true)
        let expectation = expectation(description: "Подписчик получил событие Favorites")
        var receivedEvents: [FavoritesChangeEvent] = []
        let cancellable = eventCenter.events.sink { event in
            receivedEvents.append(event)
            expectation.fulfill()
        }

        eventCenter.publish(expectedEvent)

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(receivedEvents, [expectedEvent])
        withExtendedLifetime(cancellable) {}
    }

    @MainActor
    private func makeManagers(
        favorites: TrackListMeta?,
        tracksByListId: [UUID: [Track]] = [:]
    ) -> (
        trackLists: FavoritesTrackListsManagerSpy,
        trackList: FavoritesTrackListManagerSpy
    ) {
        (
            FavoritesTrackListsManagerSpy(favorites: favorites),
            FavoritesTrackListManagerSpy(tracksByListId: tracksByListId)
        )
    }

    private func makeFavoritesMeta() -> TrackListMeta {
        TrackListMeta(
            id: UUID(),
            name: "System record",
            createdAt: Date(),
            kind: .favorites
        )
    }

    private func makeInput(
        trackId: UUID = UUID(),
        title: String? = "Title",
        artist: String? = "Artist",
        album: String? = nil,
        artworkData: Data? = nil,
        duration: Double = 120,
        fileName: String = "Track.mp3",
        isAvailable: Bool = true,
        source: TrackSource = .library,
        assetURL: URL? = nil
    ) -> FavoriteTrackInput {
        FavoriteTrackInput(
            trackId: trackId,
            title: title,
            artist: artist,
            album: album,
            artworkData: artworkData,
            duration: duration,
            fileName: fileName,
            isAvailable: isAvailable,
            source: source,
            assetURL: assetURL
        )
    }

    private func makeTrack(
        trackId: UUID,
        title: String
    ) -> Track {
        Track(
            trackId: trackId,
            title: title,
            artist: "Artist",
            duration: 120,
            fileName: "\(title).mp3",
            isAvailable: true
        )
    }

    private func makeDatabase() throws -> AppDatabase {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent("FavoritesServiceTests-\(UUID().uuidString)", isDirectory: true)
        let databaseURL = directory.appendingPathComponent("TrackList.sqlite")
        let database = AppDatabase(
            location: DatabaseLocation(databaseURL: databaseURL),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )

        try database.open()
        self.database = database
        self.databaseDirectory = directory

        return database
    }

    private func closeDatabaseForReload() throws {
        try database?.close()
        database = nil
    }

    private func reopenDatabase() throws -> AppDatabase {
        let directory = try XCTUnwrap(databaseDirectory)
        let database = AppDatabase(
            location: DatabaseLocation(databaseURL: directory.appendingPathComponent("TrackList.sqlite")),
            migrator: DatabaseMigrator(migrations: DatabaseMigration.all)
        )

        try database.open()
        self.database = database

        return database
    }
}

/// Имитирует manager метаданных, чтобы тесты сервиса не зависели от SQLite для каждого сценария.
@MainActor
private final class FavoritesTrackListsManagerSpy: TrackListsManaging {

    private(set) var ensureCalls = 0
    private(set) var currentFavorites: TrackListMeta?

    init(favorites: TrackListMeta?) {
        currentFavorites = favorites
    }

    func ensureFavoritesTrackList() throws -> TrackListMeta {
        ensureCalls += 1

        if let currentFavorites {
            return currentFavorites
        }

        let favorites = TrackListMeta(
            id: UUID(),
            name: "Created by manager",
            createdAt: Date(),
            kind: .favorites
        )
        currentFavorites = favorites
        return favorites
    }

    func favoritesTrackList() throws -> TrackListMeta? {
        currentFavorites
    }

    func loadTrackListMetas() throws -> [TrackListMeta] {
        currentFavorites.map { [$0] } ?? []
    }

    func deleteTrackList(id: UUID) throws {
        guard currentFavorites?.id == id else {
            throw AppError.trackListNotFound
        }

        currentFavorites = nil
    }

    func renameTrackList(id: UUID, to newName: String) throws {
        throw AppError.trackListRenameNotAllowed
    }

    func updateTrackListsOrder(_ orderedIds: [UUID]) throws {}
}

/// Имитирует manager содержимого и сохраняет порядок строк так же, как его видит доменный сервис.
@MainActor
private final class FavoritesTrackListManagerSpy: TrackListManaging {

    private var tracksByListId: [UUID: [Track]]
    private(set) var saveCallCount = 0
    var allowsSaving = true

    init(tracksByListId: [UUID: [Track]]) {
        self.tracksByListId = tracksByListId
    }

    func loadTracks(for id: UUID) throws -> [Track] {
        tracksByListId[id] ?? []
    }

    func saveTracks(_ tracks: [Track], for id: UUID) throws -> TrackListTracksSaveReceipt {
        guard allowsSaving else {
            throw AppError.trackListSaveFailed
        }

        tracksByListId[id] = tracks
        saveCallCount += 1
        return TrackListTracksSaveReceipt(
            trackListId: id,
            savedTracksCount: tracks.count
        )
    }

    func tracks(for id: UUID) -> [Track] {
        tracksByListId[id] ?? []
    }
}

/// Записывает точечные события Favorites, чтобы тесты проверяли публикацию без глобального event center.
private final class FavoritesEventsRecorder: FavoritesEventsPublishing {

    private(set) var events: [FavoritesChangeEvent] = []

    func publish(_ event: FavoritesChangeEvent) {
        events.append(event)
    }

    func removeAll() {
        events.removeAll()
    }
}

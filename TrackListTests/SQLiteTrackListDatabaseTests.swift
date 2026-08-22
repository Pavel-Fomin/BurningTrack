//
//  SQLiteTrackListDatabaseTests.swift
//  TrackList
//
//  Проверки persistence и порядка обычных пользовательских треклистов.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import XCTest
@testable import TrackList

final class SQLiteTrackListDatabaseTests: SQLiteDatabaseTestCase {
    @MainActor
    func testTrackListsManagerAllowsRegularTrackListNamedFavoritesToBeRenamedAndDeleted() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
        let regular = try store.createTrackList(
            id: UUID(),
            name: "Избранное",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 100),
            tracks: []
        )

        try manager.renameTrackList(id: regular.id, to: "Пользовательский")
        XCTAssertEqual(try store.fetchTrackList(id: regular.id).name, "Пользовательский")

        try manager.deleteTrackList(id: regular.id)
        XCTAssertFalse(try store.exists(id: regular.id))
    }

    @MainActor
    func testTrackListBadgeIndexAppliesTrackListMutationsWithoutReloadingUnrelatedMemberships() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListsManager = TrackListsManager(databaseStore: store)
        let trackListManager = TrackListManager(databaseStore: store)
        let sharedTrackId = UUID()
        let addedTrackId = UUID()
        let unrelatedTrackId = UUID()
        let target = try store.createTrackList(
            id: UUID(),
            name: "Target",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 100),
            tracks: [makeTrackListTrack(
                listItemId: UUID(),
                trackId: sharedTrackId,
                title: "Shared"
            )]
        )
        let unrelated = try store.createTrackList(
            id: UUID(),
            name: "Unrelated",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 200),
            tracks: [
                makeTrackListTrack(
                    listItemId: UUID(),
                    trackId: sharedTrackId,
                    title: "Shared elsewhere"
                ),
                makeTrackListTrack(
                    listItemId: UUID(),
                    trackId: unrelatedTrackId,
                    title: "Unrelated"
                )
            ]
        )
        let index = TrackListBadgeIndex(
            trackListsManager: trackListsManager,
            trackListManager: trackListManager
        )

        // Сохранение нового trackId меняет только его membership и оставляет остальные связи нетронутыми.
        try trackListManager.saveTracks(
            target.tracks + [makeTrackListTrack(
                listItemId: UUID(),
                trackId: addedTrackId,
                title: "Added"
            )],
            for: target.id
        )
        XCTAssertEqual(
            index.badges(for: [addedTrackId])[addedTrackId],
            [TrackListMembership(storedName: target.name, kind: target.kind)]
        )
        XCTAssertEqual(
            index.badges(for: [unrelatedTrackId])[unrelatedTrackId],
            [TrackListMembership(storedName: unrelated.name, kind: unrelated.kind)]
        )

        // Удаление связи target не удаляет тот же trackId из другого треклиста.
        try trackListManager.saveTracks(
            [makeTrackListTrack(
                listItemId: UUID(),
                trackId: addedTrackId,
                title: "Added"
            )],
            for: target.id
        )
        XCTAssertEqual(
            index.badges(for: [sharedTrackId])[sharedTrackId],
            [TrackListMembership(storedName: unrelated.name, kind: unrelated.kind)]
        )

        // Переименование обновляет только уже связанные с target trackId, без нового обхода всех списков.
        try trackListsManager.renameTrackList(id: target.id, to: "Renamed")
        XCTAssertEqual(
            index.badges(for: [addedTrackId])[addedTrackId],
            [TrackListMembership(storedName: "Renamed", kind: target.kind)]
        )

        // Удаление target очищает его связи через обратный индекс и сохраняет unrelated-треклист.
        try trackListsManager.deleteTrackList(id: target.id)
        XCTAssertEqual(index.badges(for: [addedTrackId])[addedTrackId], [])
        XCTAssertEqual(
            index.badges(for: [sharedTrackId])[sharedTrackId],
            [TrackListMembership(storedName: unrelated.name, kind: unrelated.kind)]
        )
    }

    func testNewRegularTrackListShiftsOnlyRegularSortOrders() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let first = try store.createTrackList(
            id: UUID(),
            name: "First",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 100),
            tracks: []
        )
        let second = try store.createTrackList(
            id: UUID(),
            name: "Second",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 200),
            tracks: []
        )
        try store.updateTrackListsOrder([first.id, second.id])
        let favorites = try store.createTrackList(
            id: UUID(),
            name: "System",
            kind: .favorites,
            createdAt: Date(timeIntervalSince1970: 300),
            tracks: []
        )
        var favoritesModel = try XCTUnwrap(trackListStore.fetch(id: favorites.id))
        favoritesModel.sortOrder = 100
        try trackListStore.upsert(favoritesModel)

        let created = try store.createTrackList(
            id: UUID(),
            name: "Created",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 400),
            tracks: []
        )

        XCTAssertEqual(try trackListStore.fetch(id: created.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: first.id)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: second.id)?.sortOrder, 2)
        XCTAssertEqual(try trackListStore.fetch(id: favorites.id)?.sortOrder, 100)
    }

    @MainActor
    func testTrackListsManagerSavesRegularOrderAcrossReloadWithoutChangingFavoritesSortOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
        let regularA = try store.createTrackList(
            id: UUID(),
            name: "A",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 100),
            tracks: []
        )
        let regularB = try store.createTrackList(
            id: UUID(),
            name: "B",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 200),
            tracks: []
        )
        let regularC = try store.createTrackList(
            id: UUID(),
            name: "C",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 300),
            tracks: []
        )
        let favorites = try manager.ensureFavoritesTrackList()
        var favoritesModel = try XCTUnwrap(trackListStore.fetch(id: favorites.id))
        favoritesModel.sortOrder = 100
        try trackListStore.upsert(favoritesModel)

        try manager.updateTrackListsOrder([
            favorites.id,
            regularC.id,
            regularA.id,
            regularB.id
        ])

        XCTAssertEqual(try trackListStore.fetch(id: regularC.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: regularA.id)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: regularB.id)?.sortOrder, 2)
        XCTAssertEqual(try trackListStore.fetch(id: favorites.id)?.sortOrder, 100)

        let reloadedManager = TrackListsManager(
            databaseStore: TrackListDatabaseStore(executor: executor)
        )
        let reloadedMetas = try reloadedManager.loadTrackListMetas()
        XCTAssertEqual(
            reloadedMetas.map(\.id),
            [regularC.id, regularA.id, regularB.id, favorites.id]
        )

        let viewModel = TrackListsViewModel(
            loader: TrackListsLoader(
                trackListsManager: TrackListsLoadingOrderSpy(metas: reloadedMetas),
                trackListManager: TrackListLoadingOrderSpy()
            ),
            initialSortMode: nil,
            loadFailurePresenter: TrackListsToastPresenterSpy(),
            eventProvider: TrackListsEventProviderSpy(),
            navigationPruning: TrackListsNavigationPruningSpy()
        )
        viewModel.loadTrackListsIfNeeded()

        XCTAssertEqual(
            viewModel.trackLists.map(\.id),
            [favorites.id, regularC.id, regularA.id, regularB.id]
        )
    }

    func testTrackListDatabaseStorePersistsBusinessModels() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackId = UUID()
        let createdAt = Date()
        let firstEntry = makeTrackListTrack(
            listItemId: UUID(),
            trackId: trackId,
            title: "First"
        )
        let secondEntry = makeTrackListTrack(
            listItemId: UUID(),
            trackId: trackId,
            title: "Second"
        )

        let created = try store.createTrackList(
            id: UUID(),
            name: "Duplicates",
            kind: .regular,
            createdAt: createdAt,
            tracks: [firstEntry, secondEntry]
        )

        XCTAssertEqual(try store.fetchMetas().map(\.id), [created.id])
        XCTAssertEqual(created.kind, .regular)
        XCTAssertEqual(try store.fetchMetas().first?.kind, .regular)
        XCTAssertEqual(try store.fetchTracks(for: created.id).map(\.id), [firstEntry.id, secondEntry.id])
        XCTAssertEqual(try store.fetchTracks(for: created.id).map(\.trackId), [trackId, trackId])

        try store.replaceTracks([secondEntry], for: created.id)

        let remainingTracks = try store.fetchTrackList(id: created.id).tracks
        XCTAssertEqual(remainingTracks.map(\.id), [secondEntry.id])
        XCTAssertEqual(remainingTracks.first?.trackId, trackId)

        try store.renameTrackList(id: created.id, to: "Renamed")
        XCTAssertEqual(try store.fetchTrackList(id: created.id).name, "Renamed")
        XCTAssertEqual(try store.fetchTrackList(id: created.id).kind, .regular)

        try store.deleteTrackList(id: created.id)
        XCTAssertFalse(try store.exists(id: created.id))
    }

    func testTrackListDatabaseStorePersistsManualTrackListOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let firstDate = Date(timeIntervalSince1970: 100)
        let secondDate = Date(timeIntervalSince1970: 200)
        let thirdDate = Date(timeIntervalSince1970: 300)
        let fourthDate = Date(timeIntervalSince1970: 400)

        let first = try store.createTrackList(
            id: UUID(),
            name: "First",
            kind: .regular,
            createdAt: firstDate,
            tracks: []
        )
        let second = try store.createTrackList(
            id: UUID(),
            name: "Second",
            kind: .regular,
            createdAt: secondDate,
            tracks: []
        )
        let third = try store.createTrackList(
            id: UUID(),
            name: "Third",
            kind: .regular,
            createdAt: thirdDate,
            tracks: []
        )

        XCTAssertEqual(try store.fetchMetas().map(\.id), [third.id, second.id, first.id])

        try store.updateTrackListsOrder([first.id, third.id, second.id])

        XCTAssertEqual(try store.fetchMetas().map(\.id), [first.id, third.id, second.id])
        XCTAssertEqual(try trackListStore.fetch(id: first.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: third.id)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: second.id)?.sortOrder, 2)

        let fourth = try store.createTrackList(
            id: UUID(),
            name: "Fourth",
            kind: .regular,
            createdAt: fourthDate,
            tracks: []
        )

        XCTAssertEqual(try store.fetchMetas().map(\.id), [fourth.id, first.id, third.id, second.id])
        XCTAssertEqual(try trackListStore.fetch(id: fourth.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: first.id)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: third.id)?.sortOrder, 2)
        XCTAssertEqual(try trackListStore.fetch(id: second.id)?.sortOrder, 3)
    }

    func testCreateTrackListNormalizesNilSortOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let olderId = UUID()
        let newerId = UUID()
        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)
        let createdDate = Date(timeIntervalSince1970: 300)

        // Старые записи могут не иметь sort_order, поэтому новый треклист нормализует их текущий fetchAll-порядок.
        try trackListStore.upsert(
            TrackListDatabaseModel(
                id: olderId,
                name: "Older",
                kind: .regular,
                createdAt: olderDate,
                updatedAt: olderDate,
                sortOrder: nil,
                isDeleted: false
            )
        )
        try trackListStore.upsert(
            TrackListDatabaseModel(
                id: newerId,
                name: "Newer",
                kind: .regular,
                createdAt: newerDate,
                updatedAt: newerDate,
                sortOrder: nil,
                isDeleted: false
            )
        )

        let created = try store.createTrackList(
            id: UUID(),
            name: "Created",
            kind: .regular,
            createdAt: createdDate,
            tracks: []
        )

        XCTAssertEqual(try store.fetchMetas().map(\.id), [created.id, newerId, olderId])
        XCTAssertEqual(try trackListStore.fetch(id: created.id)?.sortOrder, 0)
        XCTAssertEqual(try trackListStore.fetch(id: newerId)?.sortOrder, 1)
        XCTAssertEqual(try trackListStore.fetch(id: olderId)?.sortOrder, 2)
    }
}

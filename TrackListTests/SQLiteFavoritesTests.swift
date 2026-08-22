//
//  SQLiteFavoritesTests.swift
//  TrackList
//
//  Проверки системного треклиста Favorites и его ограничений.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import XCTest
@testable import TrackList

final class SQLiteFavoritesTests: SQLiteDatabaseTestCase {
    func testTrackListStorePersistsRegularAndFavoritesKinds() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = SQLiteTrackListStore(executor: executor)
        let createdAt = Date(timeIntervalSince1970: 100)
        let regular = TrackListDatabaseModel(
            id: UUID(),
            name: "Regular",
            kind: .regular,
            createdAt: createdAt,
            updatedAt: createdAt,
            sortOrder: 0,
            isDeleted: false
        )
        let favorites = TrackListDatabaseModel(
            id: UUID(),
            name: "Favorites",
            kind: .favorites,
            createdAt: createdAt,
            updatedAt: createdAt,
            sortOrder: 1,
            isDeleted: false
        )

        try store.insert(regular)
        try store.insert(favorites)

        XCTAssertEqual(try store.fetch(id: regular.id)?.kind, .regular)
        XCTAssertEqual(try store.fetch(id: favorites.id)?.kind, .favorites)

        var updatedFavorites = favorites
        updatedFavorites.name = "Renamed Favorites"
        updatedFavorites.updatedAt = createdAt.addingTimeInterval(1)
        try store.update(updatedFavorites)

        XCTAssertEqual(try store.fetch(id: favorites.id)?.kind, .favorites)
    }

    @MainActor
    func testFavoritesManagementCapabilitiesAreHiddenInPresentationState() {
        let favorites = TrackList(
            id: UUID(),
            name: "Любое название",
            createdAt: Date(timeIntervalSince1970: 100),
            kind: .favorites,
            tracks: []
        )
        let regular = TrackList(
            id: UUID(),
            name: "Избранное",
            createdAt: Date(timeIntervalSince1970: 200),
            kind: .regular,
            tracks: []
        )

        XCTAssertFalse(favorites.kind.canRename)
        XCTAssertFalse(favorites.kind.canDelete)
        XCTAssertFalse(favorites.kind.canReorder)
        XCTAssertTrue(regular.kind.canRename)
        XCTAssertTrue(regular.kind.canDelete)
        XCTAssertTrue(regular.kind.canReorder)

        let listState = TrackListsScreenStateBuilder().build(
            trackLists: [favorites, regular],
            selectedSortMode: nil
        )
        XCTAssertFalse(listState.rows[0].canDelete)
        XCTAssertFalse(listState.rows[0].canReorder)
        XCTAssertEqual(
            listState.rows[0].title,
            TrackListPresentationText.title(
                for: favorites.kind,
                storedName: favorites.name
            )
        )
        XCTAssertNotEqual(listState.rows[0].title, favorites.name)
        XCTAssertNil(listState.rows[0].createdAtText)
        XCTAssertTrue(listState.rows[1].canDelete)
        XCTAssertTrue(listState.rows[1].canReorder)
        XCTAssertEqual(listState.rows[1].title, regular.name)
        XCTAssertEqual(
            listState.rows[1].createdAtText,
            TrackListPresentationText.createdAt(regular.createdAt)
        )

        let detailState = TrackListScreenStateBuilder().build(
            id: favorites.id,
            title: favorites.name,
            kind: favorites.kind,
            canRenameTrackList: favorites.kind.canRename,
            summary: nil,
            tracks: [],
            snapshotsByTrackId: [:],
            currentTrackId: nil,
            currentContext: nil,
            isPlaying: false,
            highlightedRowId: nil,
            favoriteTrackIds: [],
            settings: AppSettings.defaultValue,
            collectionNavigationTargetsByTrackId: [:]
        )
        XCTAssertEqual(
            detailState.title,
            TrackListPresentationText.title(
                for: favorites.kind,
                storedName: favorites.name
            )
        )
        XCTAssertFalse(detailState.canRenameTrackList)
    }

    func testTrackListDatabaseStorePreservesFavoritesKindDuringMetadataUpdates() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let databaseStore = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let trackListId = UUID()
        let createdAt = Date(timeIntervalSince1970: 100)
        let favorites = TrackListDatabaseModel(
            id: trackListId,
            name: "Favorites",
            kind: .favorites,
            createdAt: createdAt,
            updatedAt: createdAt,
            sortOrder: 0,
            isDeleted: false
        )

        // Системный треклист создаётся напрямую только для проверки persistence-слоя.
        try trackListStore.insert(favorites)

        try databaseStore.renameTrackList(id: trackListId, to: "Renamed Favorites")
        XCTAssertEqual(try trackListStore.fetch(id: trackListId)?.kind, .favorites)

        try databaseStore.updateTrackListsOrder([])
        XCTAssertEqual(try trackListStore.fetch(id: trackListId)?.kind, .favorites)

        try trackListStore.markDeleted(
            id: trackListId,
            updatedAt: createdAt.addingTimeInterval(1)
        )
        XCTAssertEqual(try trackListStore.fetch(id: trackListId)?.kind, .favorites)

        try databaseStore.saveMeta(
            TrackListMeta(
                id: trackListId,
                name: "Renamed Favorites",
                createdAt: createdAt,
                kind: .favorites
            )
        )

        let restored = try XCTUnwrap(trackListStore.fetch(id: trackListId))
        XCTAssertFalse(restored.isDeleted)
        XCTAssertEqual(restored.kind, .favorites)
    }

    @MainActor
    func testTrackListsManagerRejectsFavoritesRenameAndDeletionWithoutChangingTracks() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
        let favorites = try manager.ensureFavoritesTrackList()
        let track = makeTrackListTrack(
            listItemId: UUID(),
            trackId: UUID(),
            title: "Favorite track"
        )
        try store.replaceTracks([track], for: favorites.id)

        XCTAssertThrowsError(
            try manager.renameTrackList(id: favorites.id, to: "Новое название")
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListRenameNotAllowed = appError
            else {
                return XCTFail("Ожидалась ошибка запрета переименования системного треклиста")
            }
        }
        XCTAssertThrowsError(
            try manager.deleteTrackList(id: favorites.id)
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListDeletionNotAllowed = appError
            else {
                return XCTFail("Ожидалась ошибка запрета удаления системного треклиста")
            }
        }

        let unchanged = try store.fetchTrackList(id: favorites.id)
        XCTAssertEqual(unchanged.name, favorites.name)
        XCTAssertEqual(unchanged.kind, .favorites)
        XCTAssertEqual(unchanged.tracks.map(\.id), [track.id])
    }

    @MainActor
    func testTrackListsManagerProtectsFavoritesWithDifferentDisplayName() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
        let favorites = try manager.ensureFavoritesTrackList()

        // Имитируем историческое отображаемое название без изменения назначения записи.
        try store.renameTrackList(id: favorites.id, to: "Custom favorites")

        XCTAssertThrowsError(
            try manager.renameTrackList(id: favorites.id, to: "Ещё одно название")
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListRenameNotAllowed = appError
            else {
                return XCTFail("Системный треклист должен определяться по kind, а не по названию")
            }
        }
        XCTAssertThrowsError(
            try manager.deleteTrackList(id: favorites.id)
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListDeletionNotAllowed = appError
            else {
                return XCTFail("Системный треклист должен определяться по kind, а не по названию")
            }
        }

        XCTAssertEqual(try store.fetchTrackList(id: favorites.id).name, "Custom favorites")
        XCTAssertEqual(try store.fetchTrackList(id: favorites.id).kind, .favorites)
    }

    @MainActor
    func testTrackListDatabaseStoreProtectsFavoritesMetadataDuringFullSavesAndAllowsTrackChanges() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)
        let favorites = try manager.ensureFavoritesTrackList()
        let originalTrack = makeTrackListTrack(
            listItemId: UUID(),
            trackId: UUID(),
            title: "Original"
        )
        let replacementTrack = makeTrackListTrack(
            listItemId: UUID(),
            trackId: UUID(),
            title: "Replacement"
        )
        try store.replaceTracks([originalTrack], for: favorites.id)

        XCTAssertThrowsError(
            try store.saveMeta(
                TrackListMeta(
                    id: favorites.id,
                    name: "Переименованное избранное",
                    createdAt: favorites.createdAt,
                    kind: .favorites
                )
            )
        )
        XCTAssertThrowsError(
            try store.replaceTrackLists([
                TrackList(
                    id: favorites.id,
                    name: favorites.name,
                    createdAt: favorites.createdAt,
                    kind: .regular,
                    tracks: [replacementTrack]
                )
            ])
        )

        let unchanged = try store.fetchTrackList(id: favorites.id)
        XCTAssertEqual(unchanged.name, favorites.name)
        XCTAssertEqual(unchanged.kind, .favorites)
        XCTAssertEqual(unchanged.tracks.map(\.id), [originalTrack.id])

        try store.replaceTrackLists([
            TrackList(
                id: favorites.id,
                name: favorites.name,
                createdAt: favorites.createdAt,
                kind: .favorites,
                tracks: [replacementTrack]
            )
        ])

        let updated = try store.fetchTrackList(id: favorites.id)
        XCTAssertEqual(updated.name, favorites.name)
        XCTAssertEqual(updated.kind, .favorites)
        XCTAssertEqual(updated.tracks.map(\.id), [replacementTrack.id])

        let regular = try store.createTrackList(
            id: UUID(),
            name: "Regular",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 200),
            tracks: []
        )
        XCTAssertThrowsError(
            try store.saveMeta(
                TrackListMeta(
                    id: regular.id,
                    name: regular.name,
                    createdAt: regular.createdAt,
                    kind: .favorites
                )
            )
        )
        XCTAssertEqual(try store.fetchTrackList(id: regular.id).kind, .regular)

        try store.replaceTrackLists([regular])
        let preservedFavorites = try store.fetchTrackList(id: favorites.id)
        XCTAssertEqual(preservedFavorites.kind, .favorites)
        XCTAssertEqual(preservedFavorites.tracks.map(\.id), [replacementTrack.id])
    }

    @MainActor
    func testTrackListsManagerCreatesFavoritesOnceAndKeepsUUIDAfterRecreation() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let manager = TrackListsManager(databaseStore: store)

        XCTAssertNil(try manager.favoritesTrackList())

        let first = try manager.ensureFavoritesTrackList()
        let second = try manager.ensureFavoritesTrackList()
        let recreatedManager = TrackListsManager(
            databaseStore: TrackListDatabaseStore(executor: executor)
        )
        let afterRecreation = try recreatedManager.ensureFavoritesTrackList()
        let favorites = try store.fetchMetas().filter { $0.kind == .favorites }

        XCTAssertEqual(first.kind, .favorites)
        XCTAssertEqual(first.name, "Избранное")
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(first.id, afterRecreation.id)
        XCTAssertEqual(favorites.map(\.id), [first.id])
        XCTAssertEqual(try recreatedManager.favoritesTrackList()?.id, first.id)
    }

    @MainActor
    func testTrackListsManagerCreatesFavoritesSeparatelyFromRegularWithSameName() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let regular = try store.createTrackList(
            id: UUID(),
            name: "Избранное",
            kind: .regular,
            createdAt: Date(timeIntervalSince1970: 100),
            tracks: []
        )
        let manager = TrackListsManager(databaseStore: store)

        let favorites = try manager.ensureFavoritesTrackList()
        let metas = try store.fetchMetas()

        XCTAssertEqual(regular.kind, .regular)
        XCTAssertEqual(metas.first { $0.id == regular.id }?.kind, .regular)
        XCTAssertEqual(favorites.kind, .favorites)
        XCTAssertNotEqual(favorites.id, regular.id)
        XCTAssertEqual(metas.filter { $0.kind == .favorites }.count, 1)
    }

    @MainActor
    func testTrackListsManagerRestoresSoftDeletedFavoritesWithSameUUID() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let databaseStore = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let manager = TrackListsManager(databaseStore: databaseStore)
        let favorites = try manager.ensureFavoritesTrackList()

        try trackListStore.markDeleted(id: favorites.id, updatedAt: Date())
        XCTAssertNil(try manager.favoritesTrackList())

        let restored = try manager.ensureFavoritesTrackList()
        let restoredModel = try XCTUnwrap(trackListStore.fetch(id: favorites.id))

        XCTAssertEqual(restored.id, favorites.id)
        XCTAssertFalse(restoredModel.isDeleted)
        XCTAssertEqual(restoredModel.kind, .favorites)
    }

    @MainActor
    func testTrackListsManagerDeterministicallySoftDeletesDuplicateFavorites() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let primaryID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let duplicateID = try XCTUnwrap(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let primaryDate = Date(timeIntervalSince1970: 100)
        let duplicateDate = Date(timeIntervalSince1970: 200)

        // Имитируем повреждённое историческое состояние, которое невозможно после применения индекса.
        try executor.write { database in
            try database.executeScript("DROP INDEX IF EXISTS idx_tracklists_one_active_favorites;")
        }
        try trackListStore.insert(
            makeTrackListDatabaseModel(
                id: primaryID,
                name: "Первичная запись",
                kind: .favorites,
                createdAt: primaryDate,
                isDeleted: false
            )
        )
        try trackListStore.insert(
            makeTrackListDatabaseModel(
                id: duplicateID,
                name: "Дублирующая запись",
                kind: .favorites,
                createdAt: duplicateDate,
                isDeleted: false
            )
        )

        let manager = TrackListsManager(
            databaseStore: TrackListDatabaseStore(executor: executor)
        )
        let resolved = try manager.ensureFavoritesTrackList()

        XCTAssertEqual(resolved.id, primaryID)
        XCTAssertFalse(try XCTUnwrap(trackListStore.fetch(id: primaryID)).isDeleted)
        XCTAssertTrue(try XCTUnwrap(trackListStore.fetch(id: duplicateID)).isDeleted)
    }

    func testTrackListFavoritesUniqueIndexBlocksSecondActiveRecordAndAllowsRegularRecords() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = SQLiteTrackListStore(executor: executor)
        let createdAt = Date(timeIntervalSince1970: 100)
        let firstFavorites = makeTrackListDatabaseModel(
            id: UUID(),
            name: "First favorites",
            kind: .favorites,
            createdAt: createdAt,
            isDeleted: false
        )
        let secondFavorites = makeTrackListDatabaseModel(
            id: UUID(),
            name: "Second favorites",
            kind: .favorites,
            createdAt: createdAt.addingTimeInterval(1),
            isDeleted: false
        )

        try store.insert(firstFavorites)
        XCTAssertThrowsError(try store.insert(secondFavorites))

        try store.markDeleted(id: firstFavorites.id, updatedAt: Date())
        try store.insert(secondFavorites)
        try store.insert(
            makeTrackListDatabaseModel(
                id: UUID(),
                name: "Regular one",
                kind: .regular,
                createdAt: createdAt,
                isDeleted: false
            )
        )
        try store.insert(
            makeTrackListDatabaseModel(
                id: UUID(),
                name: "Regular two",
                kind: .regular,
                createdAt: createdAt.addingTimeInterval(1),
                isDeleted: false
            )
        )

        XCTAssertTrue(try XCTUnwrap(store.fetch(id: firstFavorites.id)).isDeleted)
        XCTAssertFalse(try XCTUnwrap(store.fetch(id: secondFavorites.id)).isDeleted)
        XCTAssertEqual(try store.fetchAll().filter { $0.kind == .regular }.count, 2)
    }

    @MainActor
    func testTrackListsViewModelEnsuresFavoritesBeforePublishingList() throws {
        let favorites = TrackListMeta(
            id: UUID(),
            name: "Избранное",
            createdAt: Date(timeIntervalSince1970: 100),
            kind: .favorites
        )
        let trackListsManager = TrackListsLoadingOrderSpy(metas: [favorites])
        let viewModel = TrackListsViewModel(
            loader: TrackListsLoader(
                trackListsManager: trackListsManager,
                trackListManager: TrackListLoadingOrderSpy()
            ),
            initialSortMode: nil,
            loadFailurePresenter: TrackListsToastPresenterSpy(),
            eventProvider: TrackListsEventProviderSpy(),
            navigationPruning: TrackListsNavigationPruningSpy()
        )

        viewModel.loadTrackListsIfNeeded()

        XCTAssertEqual(trackListsManager.calls, [.ensureFavorites, .loadMetas])
        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id])
        XCTAssertEqual(viewModel.trackLists.first?.kind, .favorites)
    }

    @MainActor
    func testTrackListsViewModelPinsFavoritesBeforePersistedRegularOrder() throws {
        let database = try makeDatabase()
        let executor = try database.databaseExecutor()
        let store = TrackListDatabaseStore(executor: executor)
        let trackListStore = SQLiteTrackListStore(executor: executor)
        let regularA = TrackListMeta(
            id: UUID(),
            name: "B",
            createdAt: Date(timeIntervalSince1970: 100),
            kind: .regular
        )
        let regularB = TrackListMeta(
            id: UUID(),
            name: "A",
            createdAt: Date(timeIntervalSince1970: 200),
            kind: .regular
        )
        let favorites = TrackListMeta(
            id: UUID(),
            name: "Любое отображаемое название",
            createdAt: Date(timeIntervalSince1970: 300),
            kind: .favorites
        )

        try trackListStore.insert(
            TrackListDatabaseModel(
                id: regularA.id,
                name: regularA.name,
                kind: .regular,
                createdAt: regularA.createdAt,
                updatedAt: regularA.createdAt,
                sortOrder: 0,
                isDeleted: false
            )
        )
        try trackListStore.insert(
            TrackListDatabaseModel(
                id: regularB.id,
                name: regularB.name,
                kind: .regular,
                createdAt: regularB.createdAt,
                updatedAt: regularB.createdAt,
                sortOrder: 1,
                isDeleted: false
            )
        )
        try trackListStore.insert(
            TrackListDatabaseModel(
                id: favorites.id,
                name: favorites.name,
                kind: .favorites,
                createdAt: favorites.createdAt,
                updatedAt: favorites.createdAt,
                sortOrder: 100,
                isDeleted: false
            )
        )

        let trackListsManager = TrackListsLoadingOrderSpy(
            metas: try store.fetchMetas()
        )
        let viewModel = TrackListsViewModel(
            loader: TrackListsLoader(
                trackListsManager: trackListsManager,
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
            [favorites.id, regularA.id, regularB.id]
        )
        XCTAssertEqual(viewModel.trackLists.dropFirst().map(\.name), ["B", "A"])
    }

    @MainActor
    func testTrackListsManagerRejectsOrdersThatMoveOrOmitFavorites() throws {
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
        let favorites = try manager.ensureFavoritesTrackList()
        try manager.updateTrackListsOrder([favorites.id, regularA.id, regularB.id])
        let initialOrders = [
            try trackListStore.fetch(id: favorites.id)?.sortOrder,
            try trackListStore.fetch(id: regularA.id)?.sortOrder,
            try trackListStore.fetch(id: regularB.id)?.sortOrder
        ]

        XCTAssertThrowsError(
            try manager.updateTrackListsOrder([regularA.id, favorites.id, regularB.id])
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListReorderNotAllowed = appError
            else {
                return XCTFail("Ожидалась ошибка запрета перемещения системного треклиста")
            }
        }
        XCTAssertThrowsError(
            try manager.updateTrackListsOrder([favorites.id, regularA.id, regularA.id])
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListReorderNotAllowed = appError
            else {
                return XCTFail("Ожидалась ошибка некорректного пользовательского порядка")
            }
        }
        XCTAssertThrowsError(
            try manager.updateTrackListsOrder([favorites.id, regularA.id, UUID()])
        ) { error in
            guard let appError = error as? AppError,
                  case .trackListNotFound = appError
            else {
                return XCTFail("Ожидалась ошибка неизвестного треклиста")
            }
        }

        XCTAssertEqual(
            [
                try trackListStore.fetch(id: favorites.id)?.sortOrder,
                try trackListStore.fetch(id: regularA.id)?.sortOrder,
                try trackListStore.fetch(id: regularB.id)?.sortOrder
            ],
            initialOrders
        )
    }
}

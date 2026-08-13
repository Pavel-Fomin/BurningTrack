//
//  TrackListsMasterFlowTests.swift
//  TrackList
//
//  Проверки master-flow списка треклистов.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Combine
import XCTest
@testable import TrackList

@MainActor
final class TrackListsMasterFlowTests: XCTestCase {

    func testInitialLoadFailureAllowsRetryAndPublishesOnlySuccessfulSnapshot() {
        let favorites = makeTrackList(name: "Favorites", kind: .favorites, createdAt: 100)
        let loader = MasterLoader(results: [
            .failure(.trackListLoadFailed),
            .success([favorites])
        ])
        let loadFailures = MasterLoadFailurePresenter()
        let viewModel = makeViewModel(
            loader: loader,
            loadFailurePresenter: loadFailures
        )
        let handler = makeHandler(viewModel: viewModel)

        handler.handle(.onAppear)

        XCTAssertFalse(viewModel.hasLoadedTrackLists)
        XCTAssertTrue(viewModel.trackLists.isEmpty)
        XCTAssertTrue(viewModel.screenState.rows.isEmpty)
        XCTAssertEqual(loader.loadCallCount, 1)
        assertLoadFailure(loadFailures.errors.first, equals: .trackListLoadFailed)

        handler.handle(.onAppear)

        XCTAssertTrue(viewModel.hasLoadedTrackLists)
        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id])
        XCTAssertEqual(loader.loadCallCount, 2)
    }

    func testReloadFailurePreservesLastSuccessfulState() {
        let favorites = makeTrackList(name: "Favorites", kind: .favorites, createdAt: 100)
        let regular = makeTrackList(name: "Regular", kind: .regular, createdAt: 200)
        let loader = MasterLoader(results: [
            .success([favorites, regular]),
            .failure(.trackListLoadFailed)
        ])
        let loadFailures = MasterLoadFailurePresenter()
        let viewModel = makeViewModel(
            loader: loader,
            loadFailurePresenter: loadFailures
        )

        XCTAssertTrue(viewModel.loadTrackListsIfNeeded())
        let successfulRows = viewModel.screenState.rows

        XCTAssertFalse(viewModel.reloadTrackLists())

        XCTAssertTrue(viewModel.hasLoadedTrackLists)
        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id, regular.id])
        XCTAssertEqual(viewModel.screenState.rows, successfulRows)
        assertLoadFailure(loadFailures.errors.last, equals: .trackListLoadFailed)
    }

    func testReloadReappliesActiveSortAndBuildsPreparedRowState() {
        let favorites = makeTrackList(name: "Stored Favorites", kind: .favorites, createdAt: 100)
        let late = makeTrackList(name: "Zulu", kind: .regular, createdAt: 300)
        let early = makeTrackList(name: "Alpha", kind: .regular, createdAt: 200)
        let renamed = makeTrackList(name: "Beta", kind: .regular, createdAt: 400)
        let loader = MasterLoader(results: [
            .success([late, favorites, early]),
            .success([favorites, late, renamed])
        ])
        let viewModel = makeViewModel(loader: loader, initialSortMode: .name)

        XCTAssertTrue(viewModel.loadTrackListsIfNeeded())
        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id, early.id, late.id])
        XCTAssertEqual(
            viewModel.screenState.rows.map(\.title),
            [TrackListPresentationText.title(for: .favorites, storedName: favorites.name), "Alpha", "Zulu"]
        )
        XCTAssertNotNil(viewModel.screenState.rows[1].createdAtText)
        XCTAssertFalse(viewModel.screenState.rows[1].tracksCountText.isEmpty)

        XCTAssertTrue(viewModel.reloadTrackLists())

        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id, renamed.id, late.id])
        XCTAssertEqual(viewModel.screenState.selectedSortMode, .name)
    }

    func testSortCommandAtomicallyPreparesBothValuesThenPublishesOneInvalidation() async {
        let favorites = makeTrackList(name: "Favorites", kind: .favorites, createdAt: 100)
        let zulu = makeTrackList(name: "Zulu", kind: .regular, createdAt: 200)
        let alpha = makeTrackList(name: "Alpha", kind: .regular, createdAt: 300)
        let loader = MasterLoader(results: [
            .success([favorites, zulu, alpha]),
            .success([favorites, alpha, zulu])
        ])
        let events = MasterEventProvider()
        let manager = MasterTrackListsManager(events: events)
        let settings = MasterSettingsManager()
        let ordering = MasterOrderingStore()
        let viewModel = makeViewModel(loader: loader, eventProvider: events)
        let handler = makeHandler(
            viewModel: viewModel,
            trackListsManager: manager,
            settingsManager: settings,
            orderingStore: ordering
        )

        handler.handle(.onAppear)
        handler.handle(.setSortMode(.name))
        await yieldUntil { loader.loadCallCount == 2 }

        XCTAssertEqual(
            ordering.requests,
            [MasterOrderingStore.Request(
                sortMode: .name,
                orderedTrackListIDs: [favorites.id, alpha.id, zulu.id]
            )]
        )
        XCTAssertEqual(settings.settings.internalSettings.trackListsSortMode, .name)
        XCTAssertEqual(viewModel.sortMode, .name)
        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id, alpha.id, zulu.id])
        XCTAssertEqual(manager.publishCount, 1)
        XCTAssertEqual(loader.loadCallCount, 2)
    }

    func testFailedSortDoesNotChangePresentationOrPublishInvalidation() {
        let favorites = makeTrackList(name: "Favorites", kind: .favorites, createdAt: 100)
        let regular = makeTrackList(name: "Zulu", kind: .regular, createdAt: 200)
        let loader = MasterLoader(results: [.success([favorites, regular])])
        let events = MasterEventProvider()
        let manager = MasterTrackListsManager(events: events)
        let settings = MasterSettingsManager()
        let ordering = MasterOrderingStore(error: .trackListSaveFailed)
        let toast = MasterToastPresenter()
        let viewModel = makeViewModel(loader: loader, eventProvider: events)
        let handler = makeHandler(
            viewModel: viewModel,
            trackListsManager: manager,
            settingsManager: settings,
            orderingStore: ordering,
            toastPresenter: toast
        )

        handler.handle(.onAppear)
        handler.handle(.setSortMode(.name))

        XCTAssertNil(viewModel.sortMode)
        XCTAssertNil(settings.settings.internalSettings.trackListsSortMode)
        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id, regular.id])
        XCTAssertEqual(manager.publishCount, 0)
        assertToast(toast.errors.first, equals: .trackListSaveFailed)
    }

    func testManualMovePersistsFavoritesFirstAndUpdatesScreenStateBeforeInvalidation() {
        let favorites = makeTrackList(name: "Favorites", kind: .favorites, createdAt: 100)
        let first = makeTrackList(name: "First", kind: .regular, createdAt: 200)
        let second = makeTrackList(name: "Second", kind: .regular, createdAt: 300)
        let third = makeTrackList(name: "Third", kind: .regular, createdAt: 400)
        let loader = MasterLoader(results: [.success([favorites, first, second, third])])
        let manager = MasterTrackListsManager()
        let settings = MasterSettingsManager()
        let ordering = MasterOrderingStore()
        let viewModel = makeViewModel(loader: loader, initialSortMode: .name)
        let handler = makeHandler(
            viewModel: viewModel,
            trackListsManager: manager,
            settingsManager: settings,
            orderingStore: ordering
        )

        handler.handle(.onAppear)
        handler.handle(.moveTrackList(IndexSet(integer: 3), 1))

        XCTAssertEqual(
            ordering.requests,
            [MasterOrderingStore.Request(
                sortMode: nil,
                orderedTrackListIDs: [favorites.id, third.id, first.id, second.id]
            )]
        )
        XCTAssertNil(viewModel.sortMode)
        XCTAssertNil(settings.settings.internalSettings.trackListsSortMode)
        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id, third.id, first.id, second.id])
        XCTAssertEqual(viewModel.screenState.rows.map(\.id), [favorites.id, third.id, first.id, second.id])
        XCTAssertEqual(manager.publishCount, 1)
    }

    func testConfirmedDeleteUsesOnlyManagerInvalidationReload() async {
        let favorites = makeTrackList(name: "Favorites", kind: .favorites, createdAt: 100)
        let regular = makeTrackList(name: "Regular", kind: .regular, createdAt: 200)
        let loader = MasterLoader(results: [
            .success([favorites, regular]),
            .success([favorites])
        ])
        let events = MasterEventProvider()
        let manager = MasterTrackListsManager(events: events)
        let viewModel = makeViewModel(loader: loader, eventProvider: events)
        let handler = makeHandler(viewModel: viewModel, trackListsManager: manager)

        handler.handle(.onAppear)
        handler.handle(.requestDeleteTrackList(regular.id))
        handler.handle(.confirmDeleteTrackList(regular.id))
        await yieldUntil { loader.loadCallCount == 2 }

        XCTAssertEqual(manager.deletedIDs, [regular.id])
        XCTAssertEqual(manager.publishCount, 1)
        XCTAssertEqual(loader.loadCallCount, 2)
        XCTAssertEqual(viewModel.trackLists.map(\.id), [favorites.id])
        XCTAssertFalse(viewModel.screenState.isShowingDeleteConfirmation)
    }

    func testSuccessfulReloadPrunesCompactPathAndSidebarSelection() {
        let favorites = makeTrackList(name: "Favorites", kind: .favorites, createdAt: 100)
        let deleted = makeTrackList(name: "Deleted", kind: .regular, createdAt: 200)
        let loader = MasterLoader(results: [
            .success([favorites, deleted]),
            .success([favorites])
        ])
        let navigation = MasterNavigationPruning()
        let viewModel = makeViewModel(loader: loader, navigationPruning: navigation)

        XCTAssertTrue(viewModel.loadTrackListsIfNeeded())
        viewModel.navigationPath = [favorites.id, deleted.id]

        XCTAssertTrue(viewModel.reloadTrackLists())

        XCTAssertEqual(viewModel.navigationPath, [favorites.id])
        XCTAssertEqual(navigation.validTrackListIDSets.last, Set([favorites.id]))
    }

    func testExternalOpenReloadsMissingSnapshotAndClearsOnlyHandledRequest() {
        let favorites = makeTrackList(name: "Favorites", kind: .favorites, createdAt: 100)
        let regular = makeTrackList(name: "Regular", kind: .regular, createdAt: 200)
        let request = TrackListOpenRequest(trackListId: regular.id, requestId: UUID())
        let loader = MasterLoader(results: [
            .success([favorites]),
            .success([favorites, regular])
        ])
        let externalRequests = MasterExternalOpenRequests(request: request)
        let viewModel = makeViewModel(loader: loader)
        let handler = makeHandler(
            viewModel: viewModel,
            externalOpenRequests: externalRequests
        )

        handler.handle(.onAppear)
        handler.handlePendingExternalOpenRequest()

        XCTAssertEqual(viewModel.navigationPath, [regular.id])
        XCTAssertEqual(externalRequests.clearedRequestIDs, [request.requestId])
        XCTAssertNil(externalRequests.pendingTrackListOpenRequest)
    }

    func testExternalOpenKeepsRequestWhenReloadFails() {
        let requestedID = UUID()
        let request = TrackListOpenRequest(trackListId: requestedID, requestId: UUID())
        let loader = MasterLoader(results: [.failure(.trackListLoadFailed)])
        let externalRequests = MasterExternalOpenRequests(request: request)
        let viewModel = makeViewModel(loader: loader)
        let handler = makeHandler(
            viewModel: viewModel,
            externalOpenRequests: externalRequests
        )

        handler.handlePendingExternalOpenRequest()

        XCTAssertEqual(externalRequests.pendingTrackListOpenRequest, request)
        XCTAssertTrue(externalRequests.clearedRequestIDs.isEmpty)
        XCTAssertTrue(viewModel.navigationPath.isEmpty)
    }

    private func makeViewModel(
        loader: MasterLoader,
        initialSortMode: TrackListsSortMode? = nil,
        loadFailurePresenter: MasterLoadFailurePresenter? = nil,
        eventProvider: MasterEventProvider? = nil,
        navigationPruning: MasterNavigationPruning? = nil
    ) -> TrackListsViewModel {
        TrackListsViewModel(
            loader: loader,
            initialSortMode: initialSortMode,
            loadFailurePresenter: loadFailurePresenter ?? MasterLoadFailurePresenter(),
            eventProvider: eventProvider ?? MasterEventProvider(),
            navigationPruning: navigationPruning ?? MasterNavigationPruning()
        )
    }

    private func makeHandler(
        viewModel: TrackListsViewModel,
        trackListsManager: MasterTrackListsManager? = nil,
        settingsManager: MasterSettingsManager? = nil,
        orderingStore: MasterOrderingStore? = nil,
        toastPresenter: MasterToastPresenter? = nil,
        presenter: MasterPresenter? = nil,
        externalOpenRequests: MasterExternalOpenRequests? = nil
    ) -> TrackListsActionHandler {
        TrackListsActionHandler(
            viewModel: viewModel,
            trackListsManager: trackListsManager ?? MasterTrackListsManager(),
            settingsManager: settingsManager ?? MasterSettingsManager(),
            orderingStore: orderingStore ?? MasterOrderingStore(),
            toastPresenter: toastPresenter ?? MasterToastPresenter(),
            presenter: presenter ?? MasterPresenter(),
            externalOpenRequests: externalOpenRequests ?? MasterExternalOpenRequests()
        )
    }

    private func makeTrackList(
        name: String,
        kind: TrackListKind,
        createdAt: TimeInterval
    ) -> TrackList {
        TrackList(
            id: UUID(),
            name: name,
            createdAt: Date(timeIntervalSince1970: createdAt),
            kind: kind,
            tracks: []
        )
    }

    private func assertLoadFailure(_ actual: AppError?, equals expected: AppError) {
        switch (actual, expected) {
        case (.trackListLoadFailed?, .trackListLoadFailed):
            break
        default:
            XCTFail("Ожидалась ошибка загрузки треклистов")
        }
    }

    private func assertToast(_ actual: AppError?, equals expected: AppError) {
        switch (actual, expected) {
        case (.trackListSaveFailed?, .trackListSaveFailed):
            break
        default:
            XCTFail("Ожидалась ошибка сохранения треклистов")
        }
    }

    private func yieldUntil(_ condition: () -> Bool) async {
        for _ in 0 ..< 20 where condition() == false {
            await Task.yield()
        }
    }
}

@MainActor
private final class MasterLoader: TrackListsLoading {
    private var results: [Result<[TrackList], AppError>]
    private(set) var loadCallCount = 0

    init(results: [Result<[TrackList], AppError>]) {
        self.results = results
    }

    func loadTrackLists() throws -> [TrackList] {
        loadCallCount += 1

        guard results.isEmpty == false else {
            throw AppError.trackListLoadFailed
        }

        return try results.removeFirst().get()
    }
}

@MainActor
private final class MasterLoadFailurePresenter: TrackListsLoadFailurePresenting {
    private(set) var errors: [AppError] = []

    func presentTrackListsLoadFailure(_ error: AppError) {
        errors.append(error)
    }
}

@MainActor
private final class MasterEventProvider: TrackListsEventProviding {
    private let subject = PassthroughSubject<Void, Never>()

    var trackListsDidChange: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }

    func sendTrackListsDidChange() {
        subject.send()
    }
}

@MainActor
private final class MasterTrackListsManager: TrackListsManaging {
    private let events: MasterEventProvider?
    private(set) var deletedIDs: [UUID] = []
    private(set) var publishCount = 0

    init(events: MasterEventProvider? = nil) {
        self.events = events
    }

    func ensureFavoritesTrackList() throws -> TrackListMeta {
        throw AppError.trackListNotFound
    }

    func favoritesTrackList() throws -> TrackListMeta? {
        nil
    }

    func loadTrackListMetas() throws -> [TrackListMeta] {
        []
    }

    func deleteTrackList(id: UUID) throws {
        deletedIDs.append(id)
        publishTrackListsDidChange()
    }

    func renameTrackList(id: UUID, to newName: String) throws {
        throw AppError.trackListNotFound
    }

    func updateTrackListsOrder(_ orderedIds: [UUID]) throws {
        throw AppError.trackListReorderNotAllowed
    }

    func publishTrackListsDidChange() {
        publishCount += 1
        events?.sendTrackListsDidChange()
    }
}

@MainActor
private final class MasterSettingsManager: SettingsManaging {
    @Published private var currentSettings = AppSettings.defaultValue

    var settings: AppSettings {
        currentSettings
    }

    var settingsPublisher: Published<AppSettings>.Publisher {
        $currentSettings
    }

    func setTagReadingEnabled(_ value: Bool) {}
    func setTrackListMembershipVisible(_ value: Bool) {}
    func setFileFormatVisible(_ value: Bool) {}
    func setPurchasedITunesSourceVisible(_ value: Bool) {}
    func setMiniPlayerExpanded(_ value: Bool) {}
    func setLibraryRootDisplayMode(_ mode: LibraryRootDisplayMode) throws {}
    func setLibraryTrackSortMode(_ mode: LibraryTrackSortMode) throws {}
    func setTrackListsSortMode(_ mode: TrackListsSortMode?) throws {}

    func applyPersistedTrackListsSortMode(_ mode: TrackListsSortMode?) {
        currentSettings.internalSettings.trackListsSortMode = mode
    }
}

private final class MasterOrderingStore: TrackListsOrderingPersisting {
    struct Request: Equatable {
        let sortMode: TrackListsSortMode?
        let orderedTrackListIDs: [UUID]
    }

    private let error: AppError?
    private(set) var requests: [Request] = []

    init(error: AppError? = nil) {
        self.error = error
    }

    func persist(sortMode: TrackListsSortMode?, orderedTrackListIDs: [UUID]) throws {
        if let error {
            throw error
        }

        requests.append(
            Request(sortMode: sortMode, orderedTrackListIDs: orderedTrackListIDs)
        )
    }
}

@MainActor
private final class MasterToastPresenter: ToastPresenting {
    private(set) var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration: TimeInterval) {}

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

@MainActor
private final class MasterPresenter: TrackListsPresenting {
    private(set) var createRequestCount = 0

    func presentCreateTrackList() {
        createRequestCount += 1
    }
}

@MainActor
private final class MasterExternalOpenRequests: TrackListsExternalOpenRequestManaging {
    var pendingTrackListOpenRequest: TrackListOpenRequest?
    private(set) var clearedRequestIDs: [UUID] = []

    init(request: TrackListOpenRequest? = nil) {
        pendingTrackListOpenRequest = request
    }

    func clearTrackListOpenRequest(requestId: UUID) {
        clearedRequestIDs.append(requestId)

        guard pendingTrackListOpenRequest?.requestId == requestId else {
            return
        }

        pendingTrackListOpenRequest = nil
    }
}

@MainActor
private final class MasterNavigationPruning: TrackListsNavigationPruning {
    private(set) var validTrackListIDSets: [Set<UUID>] = []

    func pruneTrackListSelection(validTrackListIDs: Set<UUID>) {
        validTrackListIDSets.append(validTrackListIDs)
    }
}

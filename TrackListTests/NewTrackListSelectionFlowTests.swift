//
//  NewTrackListSelectionFlowTests.swift
//  TrackList
//
//  Focused-проверки flow выбора треков для нового или существующего треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет ViewModel и ActionHandler New TrackList Selection через узкие feature-зависимости.
@MainActor
final class NewTrackListSelectionFlowTests: XCTestCase {

    func testViewModelReceivesFoldersFromExplicitProvider() {
        let folder = LibraryFolder(
            name: "Музыка",
            url: URL(fileURLWithPath: "/tmp/music")
        )
        let provider = NewTrackListSelectionFoldersSpy(folders: [folder])
        let viewModel = makeViewModel(foldersProvider: provider)

        XCTAssertEqual(viewModel.state.folders, [folder])
    }

    func testToggleTrackUpdatesSelectionState() {
        let viewModel = makeViewModel()
        let track = makeLibraryTrack(name: "one.mp3")

        viewModel.handle(.toggleTrack(track))

        XCTAssertEqual(viewModel.selectedTrackIds, [track.id])
        XCTAssertEqual(viewModel.state.selectedCount, 1)
        XCTAssertTrue(viewModel.state.canSubmit)
    }

    func testRepeatedToggleRemovesSelection() {
        let viewModel = makeViewModel()
        let track = makeLibraryTrack(name: "one.mp3")

        viewModel.handle(.toggleTrack(track))
        viewModel.handle(.toggleTrack(track))

        XCTAssertTrue(viewModel.selectedTrackIds.isEmpty)
        XCTAssertEqual(viewModel.state.selectedCount, 0)
        XCTAssertFalse(viewModel.state.canSubmit)
    }

    /// Повторное подтверждение не запускает вторую доменную операцию до completion первой.
    func testRepeatedSubmitRunsCreateOnlyOnce() async {
        let manager = NewTrackListSelectionManagerSpy()
        let viewModel = makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: manager,
            toast: NewTrackListSelectionToastSpy(),
            router: NewTrackListSelectionRouterSpy()
        )
        let track = makeLibraryTrack(name: "one.mp3")

        viewModel.handle(.toggleTrack(track))
        viewModel.handle(.submit)
        viewModel.handle(.submit)
        await settleTaskQueue()

        XCTAssertEqual(manager.createdRequests.count, 1)
    }

    /// Поздний completion закрытого route не показывает feedback и не закрывает новый sheet.
    func testSubmitCompletionAfterSheetDisappearedDoesNotPresentFeedback() async {
        let manager = NewTrackListSelectionManagerSpy()
        let toast = NewTrackListSelectionToastSpy()
        let router = NewTrackListSelectionRouterSpy()
        let viewModel = makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: manager,
            toast: toast,
            router: router
        )
        let track = makeLibraryTrack(name: "one.mp3")

        viewModel.handle(.toggleTrack(track))
        viewModel.handle(.submit)
        viewModel.handle(.sheetDisappeared)
        await settleTaskQueue()

        XCTAssertEqual(manager.createdRequests.count, 1)
        XCTAssertTrue(toast.events.isEmpty)
        XCTAssertTrue(toast.errors.isEmpty)
        XCTAssertEqual(router.closeCount, 0)
    }

    func testSubmitCreateInvokesDomainCommandAndClosesFlow() async {
        let manager = NewTrackListSelectionManagerSpy()
        let toast = NewTrackListSelectionToastSpy()
        let router = NewTrackListSelectionRouterSpy()
        let handler = makeActionHandler(
            mode: .create(trackListName: "Set"),
            manager: manager,
            toast: toast,
            router: router
        )
        let track = makeLibraryTrack(name: "one.mp3")

        let result = await handler.submit(selectedTracks: [track])
        await handler.present(result)

        XCTAssertEqual(manager.createdRequests.count, 1)
        XCTAssertEqual(manager.createdRequests.first?.name, "Set")
        XCTAssertEqual(manager.createdRequests.first?.trackIDs, [track.id])
        XCTAssertEqual(toast.events, [.trackListCreated(name: "Set")])
        XCTAssertEqual(router.closeCount, 1)
    }

    func testSubmitAppendInvokesDomainCommandAndClosesFlow() async {
        let trackListID = UUID()
        let manager = NewTrackListSelectionManagerSpy()
        manager.metas = [
            TrackListMeta(
                id: trackListID,
                name: "Existing",
                createdAt: Date(),
                kind: .regular
            )
        ]
        let toast = NewTrackListSelectionToastSpy()
        let router = NewTrackListSelectionRouterSpy()
        let handler = makeActionHandler(
            mode: .append(trackListId: trackListID),
            manager: manager,
            toast: toast,
            router: router
        )
        let tracks = [
            makeLibraryTrack(name: "one.mp3"),
            makeLibraryTrack(name: "two.mp3")
        ]

        let result = await handler.submit(selectedTracks: tracks)
        await handler.present(result)

        XCTAssertEqual(manager.appendedRequests.count, 1)
        XCTAssertEqual(manager.appendedRequests.first?.trackListID, trackListID)
        XCTAssertEqual(manager.appendedRequests.first?.trackIDs, tracks.map(\.id))
        XCTAssertEqual(toast.events, [.tracksAddedToTrackList(count: 2, name: "Existing")])
        XCTAssertEqual(router.closeCount, 1)
    }

    func testEmptySelectionDoesNotInvokeDomainOrCloseFlow() async {
        let manager = NewTrackListSelectionManagerSpy()
        let router = NewTrackListSelectionRouterSpy()
        let handler = makeActionHandler(
            mode: .create(trackListName: "Set"),
            manager: manager,
            toast: NewTrackListSelectionToastSpy(),
            router: router
        )

        _ = await handler.submit(selectedTracks: [])

        XCTAssertTrue(manager.createdRequests.isEmpty)
        XCTAssertTrue(manager.appendedRequests.isEmpty)
        XCTAssertEqual(router.closeCount, 0)
    }

    func testCancelClosesFlowThroughExplicitRouter() {
        let router = NewTrackListSelectionRouterSpy()
        let handler = makeActionHandler(
            mode: .create(trackListName: "Set"),
            manager: NewTrackListSelectionManagerSpy(),
            toast: NewTrackListSelectionToastSpy(),
            router: router
        )

        handler.cancel()

        XCTAssertEqual(router.closeCount, 1)
    }

    func testDomainErrorShowsToastAndKeepsFlowOpen() async {
        let manager = NewTrackListSelectionManagerSpy()
        manager.createError = AppError.trackListSaveFailed
        let toast = NewTrackListSelectionToastSpy()
        let router = NewTrackListSelectionRouterSpy()
        let handler = makeActionHandler(
            mode: .create(trackListName: "Set"),
            manager: manager,
            toast: toast,
            router: router
        )

        let result = await handler.submit(selectedTracks: [makeLibraryTrack(name: "one.mp3")])
        await handler.present(result)

        XCTAssertEqual(router.closeCount, 0)
        XCTAssertEqual(toast.errors.count, 1)
        guard case .trackListSaveFailed? = toast.errors.first else {
            return XCTFail("Должна быть показана ошибка сохранения треклиста")
        }
    }

    private func makeViewModel() -> NewTrackListSelectionViewModel {
        makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: NewTrackListSelectionManagerSpy(),
            toast: NewTrackListSelectionToastSpy(),
            router: NewTrackListSelectionRouterSpy()
        )
    }

    private func makeViewModel(
        foldersProvider: NewTrackListSelectionFoldersSpy
    ) -> NewTrackListSelectionViewModel {
        makeViewModel(
            foldersProvider: foldersProvider,
            manager: NewTrackListSelectionManagerSpy(),
            toast: NewTrackListSelectionToastSpy(),
            router: NewTrackListSelectionRouterSpy()
        )
    }

    private func makeViewModel(
        foldersProvider: NewTrackListSelectionFoldersSpy,
        manager: NewTrackListSelectionManagerSpy,
        toast: NewTrackListSelectionToastSpy,
        router: NewTrackListSelectionRouterSpy
    ) -> NewTrackListSelectionViewModel {
        NewTrackListSelectionViewModel(
            foldersProvider: foldersProvider,
            stateBuilder: NewTrackListSelectionStateBuilder(),
            actionHandler: makeActionHandler(
                mode: .create(trackListName: "Set"),
                manager: manager,
                toast: toast,
                router: router
            )
        )
    }

    private func makeActionHandler(
        mode: NewTrackListSelectionMode,
        manager: NewTrackListSelectionManagerSpy,
        toast: NewTrackListSelectionToastSpy,
        router: NewTrackListSelectionRouterSpy
    ) -> NewTrackListSelectionActionHandler {
        NewTrackListSelectionActionHandler(
            mode: mode,
            trackListsManager: manager,
            toastPresenter: toast,
            router: router
        )
    }

    private func makeLibraryTrack(name: String) -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/\(name)"),
            title: name,
            artist: "Artist",
            duration: 180,
            addedDate: Date()
        )
    }

    /// Передаёт выполнение в task, созданную ViewModel, без обращения к таймерам.
    private func settleTaskQueue() async {
        for _ in 0..<16 {
            await Task.yield()
        }
    }
}

/// Небольшой fake доменного фасада для focused-тестов New TrackList Selection.
@MainActor
private final class NewTrackListSelectionManagerSpy: TrackListFlowManaging {
    struct CreateRequest {
        let name: String
        let trackIDs: [UUID]
    }

    struct AppendRequest {
        let trackListID: UUID
        let trackIDs: [UUID]
    }

    var createdRequests: [CreateRequest] = []
    var appendedRequests: [AppendRequest] = []
    var metas: [TrackListMeta] = []
    var createError: Error?
    var appendError: Error?
    var loadMetasError: Error?

    func createEmptyTrackList(withName name: String) throws -> TrackList {
        makeTrackList(name: name)
    }

    func createTrackList(
        from libraryTracks: [LibraryTrack],
        withName name: String
    ) throws -> TrackList {
        if let createError {
            throw createError
        }

        createdRequests.append(
            CreateRequest(name: name, trackIDs: libraryTracks.map(\.id))
        )
        return makeTrackList(name: name)
    }

    func loadTrackListMetas() throws -> [TrackListMeta] {
        if let loadMetasError {
            throw loadMetasError
        }

        return metas
    }

    func addTracks(
        _ libraryTracks: [LibraryTrack],
        to trackListId: UUID
    ) throws -> Bool {
        if let appendError {
            throw appendError
        }

        appendedRequests.append(
            AppendRequest(trackListID: trackListId, trackIDs: libraryTracks.map(\.id))
        )
        return true
    }

    private func makeTrackList(name: String) -> TrackList {
        TrackList(
            id: UUID(),
            name: name,
            createdAt: Date(),
            kind: .regular,
            tracks: []
        )
    }
}

/// Предоставляет фиксированный снимок папок для проверки ViewModel без MusicLibraryManager.
@MainActor
private final class NewTrackListSelectionFoldersSpy: LibraryFoldersProviding {
    let attachedFolders: [LibraryFolder]

    init(folders: [LibraryFolder]) {
        attachedFolders = folders
    }
}

/// Запоминает события и ошибки, отправленные selection-flow в presentation-слой.
@MainActor
private final class NewTrackListSelectionToastSpy: ToastPresenting {
    var events: [ToastEvent] = []
    var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Проверяет закрытие selection-flow без зависимости от SheetManager.
@MainActor
private final class NewTrackListSelectionRouterSpy: NewTrackListSelectionRouting {
    var closeCount = 0
    private(set) var dismissedRouteIDs: [UUID] = []

    func dismissNewTrackListSelection(_ routeID: UUID) {
        closeCount += 1
        dismissedRouteIDs.append(routeID)
    }
}

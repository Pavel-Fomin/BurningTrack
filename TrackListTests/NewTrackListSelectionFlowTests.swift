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

        XCTAssertEqual(viewModel.state.selectedTrackIDs, [track.id])
        XCTAssertEqual(viewModel.state.selectedCount, 1)
        XCTAssertTrue(viewModel.state.canSubmit)
    }

    func testRepeatedToggleRemovesSelection() {
        let viewModel = makeViewModel()
        let track = makeLibraryTrack(name: "one.mp3")

        viewModel.handle(.toggleTrack(track))
        viewModel.handle(.toggleTrack(track))

        XCTAssertTrue(viewModel.state.selectedTrackIDs.isEmpty)
        XCTAssertEqual(viewModel.state.selectedCount, 0)
        XCTAssertFalse(viewModel.state.canSubmit)
    }

    /// Недоступная строка показывает Toast и не меняет selection sheet-flow.
    func testUnavailableTrackShowsToastWithoutChangingSelection() {
        let toast = NewTrackListSelectionToastSpy()
        let viewModel = makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: NewTrackListSelectionManagerSpy(),
            toast: toast,
            router: NewTrackListSelectionRouterSpy()
        )
        let track = makeLibraryTrack(name: "Unavailable.m4a")

        viewModel.handle(.unavailableTrackTapped(track))

        XCTAssertEqual(toast.events, [.trackUnavailable(title: track.title)])
        XCTAssertTrue(viewModel.state.selectedTrackIDs.isEmpty)
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

    func testScreenAppearedRefreshesFoldersFromExplicitProvider() {
        let oldFolder = makeFolder(name: "Старая папка")
        let newFolder = makeFolder(name: "Новая папка")
        let provider = NewTrackListSelectionFoldersSpy(folders: [oldFolder])
        let viewModel = makeViewModel(foldersProvider: provider)

        provider.attachedFolders = [newFolder]
        viewModel.handle(.screenAppeared)

        XCTAssertEqual(viewModel.state.folders, [newFolder])
    }

    func testSingleSelectionsKeepUserOrderForCreate() async {
        let manager = NewTrackListSelectionManagerSpy()
        let viewModel = makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: manager,
            toast: NewTrackListSelectionToastSpy(),
            router: NewTrackListSelectionRouterSpy()
        )
        let tracks = [
            makeLibraryTrack(name: "A.mp3"),
            makeLibraryTrack(name: "B.mp3"),
            makeLibraryTrack(name: "C.mp3")
        ]

        tracks.forEach { viewModel.handle(.toggleTrack($0)) }
        viewModel.handle(.submit)
        await settleTaskQueue()

        XCTAssertEqual(manager.createdRequests.first?.trackIDs, tracks.map(\.id))
    }

    func testDeselectAndReselectMovesTrackToEndOfSubmitOrder() async {
        let manager = NewTrackListSelectionManagerSpy()
        let viewModel = makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: manager,
            toast: NewTrackListSelectionToastSpy(),
            router: NewTrackListSelectionRouterSpy()
        )
        let trackA = makeLibraryTrack(name: "A.mp3")
        let trackB = makeLibraryTrack(name: "B.mp3")

        viewModel.handle(.toggleTrack(trackA))
        viewModel.handle(.toggleTrack(trackB))
        viewModel.handle(.toggleTrack(trackA))
        viewModel.handle(.toggleTrack(trackA))
        viewModel.handle(.submit)
        await settleTaskQueue()

        XCTAssertEqual(manager.createdRequests.first?.trackIDs, [trackB.id, trackA.id])
    }

    func testSelectAllAppendsOnlyMissingTracksInVisibleOrder() async {
        let manager = NewTrackListSelectionManagerSpy()
        let viewModel = makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: manager,
            toast: NewTrackListSelectionToastSpy(),
            router: NewTrackListSelectionRouterSpy()
        )
        let trackX = makeLibraryTrack(name: "X.mp3")
        let trackA = makeLibraryTrack(name: "A.mp3")
        let trackB = makeLibraryTrack(name: "B.mp3")
        let trackC = makeLibraryTrack(name: "C.mp3")
        let trackD = makeLibraryTrack(name: "D.mp3")

        viewModel.handle(.toggleTrack(trackX))
        viewModel.handle(.toggleTrack(trackB))
        viewModel.handle(.selectAll([trackA, trackB, trackC, trackD]))
        viewModel.handle(.submit)
        await settleTaskQueue()

        XCTAssertEqual(
            manager.createdRequests.first?.trackIDs,
            [trackX.id, trackB.id, trackA.id, trackC.id, trackD.id]
        )
    }

    func testDeselectAllPreservesOrderOfTracksOutsideFolder() async {
        let manager = NewTrackListSelectionManagerSpy()
        let viewModel = makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: manager,
            toast: NewTrackListSelectionToastSpy(),
            router: NewTrackListSelectionRouterSpy()
        )
        let trackX = makeLibraryTrack(name: "X.mp3")
        let trackA = makeLibraryTrack(name: "A.mp3")
        let trackB = makeLibraryTrack(name: "B.mp3")
        let trackC = makeLibraryTrack(name: "C.mp3")
        let trackY = makeLibraryTrack(name: "Y.mp3")

        [trackX, trackA, trackB, trackC, trackY].forEach {
            viewModel.handle(.toggleTrack($0))
        }
        viewModel.handle(.deselectAll([trackA, trackB, trackC]))
        viewModel.handle(.submit)
        await settleTaskQueue()

        XCTAssertEqual(manager.createdRequests.first?.trackIDs, [trackX.id, trackY.id])
    }

    func testCrossFolderSelectionsKeepOneGlobalOrder() async {
        let manager = NewTrackListSelectionManagerSpy()
        let viewModel = makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: manager,
            toast: NewTrackListSelectionToastSpy(),
            router: NewTrackListSelectionRouterSpy()
        )
        let trackA = makeLibraryTrack(name: "Folder1-A.mp3")
        let trackB = makeLibraryTrack(name: "Folder1-B.mp3")
        let trackC = makeLibraryTrack(name: "Folder2-C.mp3")
        let trackD = makeLibraryTrack(name: "Folder1-D.mp3")

        [trackA, trackB, trackC, trackD].forEach {
            viewModel.handle(.toggleTrack($0))
        }
        viewModel.handle(.submit)
        await settleTaskQueue()

        XCTAssertEqual(
            manager.createdRequests.first?.trackIDs,
            [trackA.id, trackB.id, trackC.id, trackD.id]
        )
    }

    func testDuplicateSelectAllKeepsExistingOrderWithoutDuplicates() async {
        let manager = NewTrackListSelectionManagerSpy()
        let viewModel = makeViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            manager: manager,
            toast: NewTrackListSelectionToastSpy(),
            router: NewTrackListSelectionRouterSpy()
        )
        let trackA = makeLibraryTrack(name: "A.mp3")
        let trackB = makeLibraryTrack(name: "B.mp3")

        viewModel.handle(.selectAll([trackA, trackB]))
        viewModel.handle(.selectAll([trackB, trackA]))
        viewModel.handle(.submit)
        await settleTaskQueue()

        XCTAssertEqual(manager.createdRequests.first?.trackIDs, [trackA.id, trackB.id])
    }

    func testOrderedSelectionIsPassedToAppendDomainCommand() async {
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
        let router = NewTrackListSelectionRouterSpy()
        let viewModel = NewTrackListSelectionViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            stateBuilder: NewTrackListSelectionStateBuilder(),
            actionHandler: makeActionHandler(
                mode: .append(trackListId: trackListID),
                manager: manager,
                toast: NewTrackListSelectionToastSpy(),
                router: router
            )
        )
        let tracks = [
            makeLibraryTrack(name: "A.mp3"),
            makeLibraryTrack(name: "B.mp3"),
            makeLibraryTrack(name: "C.mp3")
        ]

        tracks.forEach { viewModel.handle(.toggleTrack($0)) }
        viewModel.handle(.submit)
        await settleTaskQueue()

        XCTAssertEqual(manager.appendedRequests.first?.trackIDs, tracks.map(\.id))
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

    /// Session может закрыться после domain completion, пока строится track-style Toast одного добавленного трека.
    func testSingleTrackAppendAfterSheetDisappearedDuringFeedbackPreparationDoesNotPresent() async {
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
        let feedbackPreparer = NewTrackListSelectionControlledFeedbackPreparer()
        let viewModel = NewTrackListSelectionViewModel(
            foldersProvider: NewTrackListSelectionFoldersSpy(folders: []),
            stateBuilder: NewTrackListSelectionStateBuilder(),
            actionHandler: makeActionHandler(
                mode: .append(trackListId: trackListID),
                manager: manager,
                toast: toast,
                router: router,
                feedbackPreparer: feedbackPreparer
            )
        )
        let track = makeLibraryTrack(name: "one.mp3")

        viewModel.handle(.toggleTrack(track))
        viewModel.handle(.submit)
        await feedbackPreparer.waitUntilPreparationStarted()

        viewModel.handle(.sheetDisappeared)
        feedbackPreparer.resume(
            with: .tracksAddedToTrackList(count: 1, name: "Existing")
        )
        await settleTaskQueue()

        XCTAssertEqual(manager.appendedRequests.count, 1)
        XCTAssertEqual(manager.appendedRequests.first?.trackIDs, [track.id])
        XCTAssertEqual(feedbackPreparer.requestedTrackIDs, [track.id])
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
        let presentation = await handler.preparePresentation(result)
        handler.present(presentation)

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
        let presentation = await handler.preparePresentation(result)
        handler.present(presentation)

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
        let presentation = await handler.preparePresentation(result)
        handler.present(presentation)

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
        router: NewTrackListSelectionRouterSpy,
        feedbackPreparer: (any NewTrackListSelectionFeedbackPreparing)? = nil
    ) -> NewTrackListSelectionActionHandler {
        NewTrackListSelectionActionHandler(
            mode: mode,
            trackListsManager: manager,
            toastPresenter: toast,
            router: router,
            feedbackPreparer: feedbackPreparer
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

    private func makeFolder(name: String) -> LibraryFolder {
        LibraryFolder(
            name: name,
            url: URL(fileURLWithPath: "/tmp/\(name)")
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
    var attachedFolders: [LibraryFolder]

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

/// Детерминированно удерживает async-подготовку одного track-style Toast до явного resume тестом.
@MainActor
private final class NewTrackListSelectionControlledFeedbackPreparer: NewTrackListSelectionFeedbackPreparing {
    private var preparationStarted = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var resultContinuation: CheckedContinuation<ToastEvent, Never>?
    private(set) var requestedTrackIDs: [UUID] = []

    /// Фиксирует реальный single-track путь и приостанавливает его перед presentation side effect.
    func trackAddedToTrackList(
        track: LibraryTrack,
        trackListName: String
    ) async -> ToastEvent {
        requestedTrackIDs.append(track.id)
        preparationStarted = true
        startContinuation?.resume()
        startContinuation = nil

        return await withCheckedContinuation { continuation in
            resultContinuation = continuation
        }
    }

    /// Возвращается только после того, как ViewModel дошла до suspend point подготовки feedback.
    func waitUntilPreparationStarted() async {
        guard preparationStarted == false else { return }

        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    /// Завершает подготовку после управляемого lifecycle-события sheet.
    func resume(with event: ToastEvent) {
        resultContinuation?.resume(returning: event)
        resultContinuation = nil
    }
}

//
//  LibraryTracksPresenterTests.swift
//  TrackList
//
//  Проверки presentation-состояния Library Tracks без запуска симулятора.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class LibraryTracksPresenterTests: XCTestCase {

    /// Проверяет loading, empty-state и данные панели для выбранного batch-действия.
    func testMakeStateRepresentsLoadingEmptyListAndSelectionAction() {
        let receiver = LibraryTracksStateReceiverSpy()
        let presenter = LibraryTracksPresenter(
            output: receiver,
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        let selectedTrackID = UUID()
        var selection = BulkSelectionState<UUID, BulkTrackAction>()
        selection.activate(action: .renameFiles)
        selection.selection.toggle(selectedTrackID)

        let state = presenter.makeState(
            sections: [],
            isLoading: true,
            didLoad: true,
            sortMode: .titleAsc,
            selection: selection,
            membershipsById: [:],
            isBatchFilenameRenameFlowActive: false
        )

        XCTAssertTrue(state.isLoading)
        XCTAssertTrue(state.isEmpty)
        XCTAssertTrue(state.isSelecting)
        XCTAssertEqual(state.selectedTrackIDs.ids, [selectedTrackID])
        XCTAssertEqual(state.selectionActionBarState?.selectedCount, 1)
        XCTAssertEqual(state.selectionActionBarState?.pendingAction, .renameFiles)
        XCTAssertTrue(state.selectionActionBarState?.isActionEnabled == true)

        presenter.present(state)
        XCTAssertEqual(receiver.receivedState, state)
    }

    /// Проверяет, что активный режим выбора всегда публикует нижнюю панель.
    func testSelectionModeAlwaysShowsActionBar() {
        let coordinator = LibrarySelectionActionBarCoordinator()

        let activeState = coordinator.makeState(
            isSelecting: true,
            pendingAction: nil,
            selectedCount: 0,
            hasSelection: false
        )
        let inactiveState = coordinator.makeState(
            isSelecting: false,
            pendingAction: .addToPlayer,
            selectedCount: 1,
            hasSelection: true
        )

        XCTAssertNotNil(activeState)
        XCTAssertNil(inactiveState)
    }

    /// Проверяет, что pendingAction меняет содержание, но не существование панели.
    func testPendingActionDoesNotControlActionBarVisibility() {
        let coordinator = LibrarySelectionActionBarCoordinator()
        let selectionOnlyState = coordinator.makeState(
            isSelecting: true,
            pendingAction: nil,
            selectedCount: 1,
            hasSelection: true
        )
        let actionState = coordinator.makeState(
            isSelecting: true,
            pendingAction: .addToPlayer,
            selectedCount: 1,
            hasSelection: true
        )

        XCTAssertNotNil(selectionOnlyState)
        XCTAssertNotNil(actionState)
        XCTAssertNil(selectionOnlyState?.pendingAction)
        XCTAssertEqual(actionState?.pendingAction, .addToPlayer)
        XCTAssertNil(
            selectionOnlyState.map { coordinator.makeConfig(from: $0) }?.primaryTitle
        )
        XCTAssertEqual(
            actionState.map { coordinator.makeConfig(from: $0) }?.primaryTitle,
            "Apply"
        )
    }

    /// Проверяет, что toggle строки не завершает обычный режим выбора.
    func testSelectingTrackDoesNotLeaveSelectionMode() {
        let receiver = LibraryTracksStateReceiverSpy()
        let screenFlow = LibraryTracksActionStateFlowSpy()
        let handler = makeActionHandler(
            output: screenFlow,
            receiver: receiver
        )

        handler.handle(.selectionStarted)
        handler.handle(.trackSelectionToggled(screenFlow.selectedTrackID))

        XCTAssertTrue(receiver.receivedState?.isSelecting == true)
        XCTAssertEqual(receiver.receivedState?.selectedTrackIDs.ids, [screenFlow.selectedTrackID])
        XCTAssertNotNil(receiver.receivedState?.selectionActionBarState)
        XCTAssertNil(receiver.receivedState?.selectionActionBarState?.pendingAction)
    }

    /// Проверяет, что Presenter передаёт в host актуальный счётчик, а не первый snapshot выбора.
    func testChangingSelectionUpdatesActionBarCount() {
        let presenter = LibraryTracksPresenter(
            output: LibraryTracksStateReceiverSpy(),
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        var selection = BulkSelectionState<UUID, BulkTrackAction>()
        selection.activate(action: .addToPlayer)
        selection.selection.toggle(UUID())
        selection.selection.toggle(UUID())
        selection.selection.toggle(UUID())

        let state = presenter.makeState(
            sections: [],
            isLoading: false,
            didLoad: true,
            sortMode: .fileDateDesc,
            selection: selection,
            membershipsById: [:],
            isBatchFilenameRenameFlowActive: false
        )

        XCTAssertEqual(state.selectionActionBarState?.selectedCount, 3)
    }

    /// Проверяет, что отмена выбора удаляет состояние панели у host-экрана.
    func testCancellingSelectionHidesActionBar() {
        let presenter = LibraryTracksPresenter(
            output: LibraryTracksStateReceiverSpy(),
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        var selection = BulkSelectionState<UUID, BulkTrackAction>()
        selection.activate(action: .addToPlayer)
        selection.selection.toggle(UUID())
        selection.reset()

        let state = presenter.makeState(
            sections: [],
            isLoading: false,
            didLoad: true,
            sortMode: .fileDateDesc,
            selection: selection,
            membershipsById: [:],
            isBatchFilenameRenameFlowActive: false
        )

        XCTAssertNil(state.selectionActionBarState)
    }

    /// Проверяет, что выбранное действие меняет содержимое уже существующей панели.
    func testBatchActionSelectionImmediatelyShowsActionBar() {
        let receiver = LibraryTracksStateReceiverSpy()
        let screenFlow = LibraryTracksActionStateFlowSpy()
        let handler = makeActionHandler(
            output: screenFlow,
            receiver: receiver
        )

        handler.handle(.batchActionSelected(.addToPlayer))

        XCTAssertTrue(receiver.receivedState?.isSelecting == true)
        XCTAssertEqual(receiver.receivedState?.selectedTrackIDs.count, 0)
        XCTAssertEqual(receiver.receivedState?.selectionActionBarState?.pendingAction, .addToPlayer)
        XCTAssertEqual(receiver.receivedState?.selectionActionBarState?.selectedCount, 0)
        XCTAssertFalse(receiver.receivedState?.selectionActionBarState?.isActionEnabled == true)
    }

    /// Проверяет, что selection после выбора действия сохраняет режим и делает Apply доступным.
    func testSelectingTrackForPendingActionKeepsSelectionActive() {
        let receiver = LibraryTracksStateReceiverSpy()
        let screenFlow = LibraryTracksActionStateFlowSpy()
        let handler = makeActionHandler(
            output: screenFlow,
            receiver: receiver
        )

        handler.handle(.batchActionSelected(.addToPlayer))
        handler.handle(.trackSelectionToggled(screenFlow.selectedTrackID))

        XCTAssertTrue(receiver.receivedState?.isSelecting == true)
        XCTAssertEqual(receiver.receivedState?.selectionActionBarState?.pendingAction, .addToPlayer)
        XCTAssertEqual(receiver.receivedState?.selectionActionBarState?.selectedCount, 1)
        XCTAssertTrue(receiver.receivedState?.selectionActionBarState?.isActionEnabled == true)
    }

    /// Проверяет преобразование typed state в config, который Binding передаёт LibraryScreen host-у.
    func testActionBarStateProducesHostConfig() {
        let coordinator = LibrarySelectionActionBarCoordinator()
        let state = coordinator.makeState(
            isSelecting: true,
            pendingAction: .addToPlayer,
            selectedCount: 0,
            hasSelection: false
        )

        guard let state else {
            return XCTFail("После выбора batch-действия должен быть сформирован action bar state")
        }
        let config = coordinator.makeConfig(from: state)

        XCTAssertEqual(
            config.title,
            LibraryPresentationText.bulkActionTitle(for: .addToPlayer)
        )
        XCTAssertEqual(
            config.subtitle,
            LibraryPresentationText.selectedTrackCountText(for: 0)
        )
        XCTAssertFalse(config.isPrimaryEnabled)
    }

    /// Проверяет, что готовые секции и выбранный режим сортировки передаются без логики во View.
    func testMakeStateRepresentsSectionsAndSortMode() {
        let presenter = LibraryTracksPresenter(
            output: LibraryTracksStateReceiverSpy(),
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        let track = LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/Presenter.flac"),
            title: "Presenter",
            artist: "Artist",
            duration: 120,
            addedDate: Date()
        )
        let sections = [
            TrackSection(id: "flat", header: .hidden, tracks: [track])
        ]

        let state = presenter.makeState(
            sections: sections,
            isLoading: false,
            didLoad: true,
            sortMode: .artistDesc,
            selection: BulkSelectionState(),
            membershipsById: [:],
            isBatchFilenameRenameFlowActive: false
        )

        XCTAssertEqual(state.sections, sections)
        XCTAssertEqual(state.sortMode, .artistDesc)
        XCTAssertFalse(state.isEmpty)
    }

    /// Проверяет typed-маршрут базовых действий без View, SheetManager и файловых операций.
    func testActionHandlerRoutesSelectionAndRefreshActions() async {
        let output = LibraryTracksActionOutputSpy()
        var batchRenameApplyCallCount = 0
        let handler = LibraryTracksActionHandler(
            output: output,
            applyBatchFilenameRename: {
                batchRenameApplyCallCount += 1
            }
        )

        handler.handle(.screenAppeared)
        handler.handle(.sortModeSelected(.artistAsc))
        handler.handle(.selectionStarted)
        handler.handle(.trackSelectionToggled(UUID(uuidString: "00000000-0000-0000-0000-000000000001")!))
        handler.handle(.selectAllToggled)
        handler.handle(.batchActionSelected(.editTags))
        handler.handle(.batchActionConfirmed)
        handler.handle(.batchFilenameRenameApplyRequested)
        handler.handle(.selectionCancelled)
        handler.handle(.screenClosed)
        handler.handle(.refreshRequested)
        for _ in 0..<3 {
            await Task.yield()
        }

        XCTAssertEqual(output.loadIfNeededCallCount, 1)
        XCTAssertEqual(output.selectedSortModes, [.artistAsc])
        XCTAssertEqual(output.startSelectionCallCount, 1)
        XCTAssertEqual(output.toggledTrackIDs.count, 1)
        XCTAssertEqual(output.toggleSelectAllCallCount, 1)
        XCTAssertEqual(output.selectedBatchActions, [.editTags])
        XCTAssertEqual(output.confirmBatchActionCallCount, 1)
        XCTAssertEqual(batchRenameApplyCallCount, 1)
        XCTAssertEqual(output.cancelSelectionCallCount, 2)
        XCTAssertEqual(output.refreshCallCount, 1)
    }

    /// Проверяет завершение selection при фактическом закрытии folder destination.
    func testClosingFolderDestinationClearsSelectionActionBar() {
        let receiver = LibraryTracksStateReceiverSpy()
        let screenFlow = LibraryTracksActionStateFlowSpy()
        let presenter = LibraryTracksPresenter(
            output: receiver,
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        screenFlow.configure(presenter: presenter)
        let handler = LibraryTracksActionHandler(
            output: screenFlow,
            applyBatchFilenameRename: {}
        )

        handler.handle(.batchActionSelected(.addToPlayer))
        handler.handle(.trackSelectionToggled(screenFlow.selectedTrackID))
        XCTAssertEqual(receiver.receivedState?.selectionActionBarState?.selectedCount, 1)

        handler.handle(.screenClosed)

        XCTAssertFalse(receiver.receivedState?.isSelecting == true)
        XCTAssertTrue(receiver.receivedState?.selectedTrackIDs.isEmpty == true)
        XCTAssertNil(receiver.receivedState?.selectionActionBarState)
    }

    /// Проверяет, что техническое обновление пути с той же активной папкой не закрывает selection.
    func testUnchangedFolderRouteDoesNotCloseSelection() {
        let parentFolderID = UUID()
        let activeFolderID = UUID()

        XCTAssertFalse(
            LibraryFolderRouteClosureEvaluator.didCloseActiveFolder(
                from: [.folder(parentFolderID), .folder(activeFolderID)],
                to: [.folder(activeFolderID)]
            )
        )
    }

    /// Проверяет, что удаление активной folder route закрывает selection через typed action.
    func testActualFolderRouteRemovalClosesSelection() {
        let folderID = UUID()
        let oldPath: [NavigationCoordinator.LibraryRoute] = [.folder(folderID)]
        let receiver = LibraryTracksStateReceiverSpy()
        let screenFlow = LibraryTracksActionStateFlowSpy()
        let handler = makeActionHandler(
            output: screenFlow,
            receiver: receiver
        )

        handler.handle(.batchActionSelected(.addToPlayer))
        handler.handle(.trackSelectionToggled(screenFlow.selectedTrackID))

        if LibraryFolderRouteClosureEvaluator.didCloseActiveFolder(
            from: oldPath,
            to: []
        ) {
            handler.handle(.screenClosed)
        }

        XCTAssertFalse(receiver.receivedState?.isSelecting == true)
        XCTAssertNil(receiver.receivedState?.selectionActionBarState)
    }

    /// Проверяет передачу подтверждённого действия и ID треков в порядке выбора.
    func testApplyExecutesPendingAction() {
        let receiver = LibraryTracksStateReceiverSpy()
        let screenFlow = LibraryTracksActionStateFlowSpy()
        let handler = makeActionHandler(
            output: screenFlow,
            receiver: receiver
        )
        let firstTrackID = screenFlow.selectedTrackID
        let secondTrackID = UUID()

        handler.handle(.batchActionSelected(.addToPlayer))
        handler.handle(.trackSelectionToggled(firstTrackID))
        handler.handle(.trackSelectionToggled(secondTrackID))
        handler.handle(.batchActionConfirmed)

        XCTAssertEqual(
            screenFlow.appliedPendingActions,
            [
                PendingBulkTrackActionExpectation(
                    action: .addToPlayer,
                    trackIDs: [firstTrackID, secondTrackID]
                )
            ]
        )

        var receivedAction: BulkTrackAction?
        var receivedTrackIDs: [UUID] = []
        let batchHandler = LibraryBatchActionHandler(
            onAddToPlayer: { pendingAction in
                receivedAction = pendingAction.action
                receivedTrackIDs = pendingAction.trackIDs
            },
            onAddToTrackList: { _ in },
            onRenameFiles: { _ in },
            onEditTags: { _ in }
        )
        let accepted = batchHandler.handle(
            PendingBulkTrackAction(
                action: .addToPlayer,
                trackIDs: [firstTrackID, secondTrackID]
            )
        )

        XCTAssertTrue(accepted)
        XCTAssertEqual(receivedAction, .addToPlayer)
        XCTAssertEqual(receivedTrackIDs, [firstTrackID, secondTrackID])
        XCTAssertFalse(receiver.receivedState?.isSelecting == true)
        XCTAssertNil(receiver.receivedState?.selectionActionBarState)
    }

    /// Проверяет сквозной маршрут screen actions через handler, screen-flow и Presenter до состояния View.
    func testActionsPublishStateThroughPresenter() async {
        let receiver = LibraryTracksStateReceiverSpy()
        let screenFlow = LibraryTracksActionStateFlowSpy()
        let presenter = LibraryTracksPresenter(
            output: receiver,
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        screenFlow.configure(presenter: presenter)

        var batchRenameApplyCallCount = 0
        let handler = LibraryTracksActionHandler(
            output: screenFlow,
            applyBatchFilenameRename: {
                batchRenameApplyCallCount += 1
            }
        )

        handler.handle(.screenAppeared)
        for _ in 0..<3 {
            await Task.yield()
        }
        XCTAssertTrue(receiver.receivedState?.didLoad == true)
        XCTAssertTrue(receiver.receivedState?.isLoading == true)

        handler.handle(.sortModeSelected(.artistAsc))
        for _ in 0..<3 {
            await Task.yield()
        }
        XCTAssertEqual(receiver.receivedState?.sortMode, .artistAsc)

        handler.handle(.selectionStarted)
        handler.handle(.trackSelectionToggled(screenFlow.selectedTrackID))

        XCTAssertTrue(receiver.receivedState?.isSelecting == true)
        XCTAssertEqual(receiver.receivedState?.selectedTrackIDs.ids, [screenFlow.selectedTrackID])
        XCTAssertNotNil(receiver.receivedState?.selectionActionBarState)
        XCTAssertNil(receiver.receivedState?.selectionActionBarState?.pendingAction)

        handler.handle(.batchActionSelected(.renameFiles))
        XCTAssertTrue(receiver.receivedState?.isSelecting == true)
        XCTAssertEqual(receiver.receivedState?.selectionActionBarState?.pendingAction, .renameFiles)

        handler.handle(.batchActionConfirmed)
        XCTAssertEqual(
            screenFlow.appliedPendingActions,
            [
                PendingBulkTrackActionExpectation(
                    action: .renameFiles,
                    trackIDs: [screenFlow.selectedTrackID]
                )
            ]
        )
        XCTAssertFalse(receiver.receivedState?.isSelecting == true)

        handler.handle(.batchFilenameRenameApplyRequested)
        handler.handle(.selectionCancelled)
        for _ in 0..<3 {
            await Task.yield()
        }

        XCTAssertEqual(batchRenameApplyCallCount, 1)
        XCTAssertFalse(receiver.receivedState?.isSelecting == true)
        XCTAssertNil(receiver.receivedState?.selectionActionBarState)
    }

    /// Собирает реальный маршрут ActionHandler → Presenter для тестов переходов без SwiftUI View.
    private func makeActionHandler(
        output: LibraryTracksActionStateFlowSpy,
        receiver: LibraryTracksStateReceiverSpy
    ) -> LibraryTracksActionHandler {
        let presenter = LibraryTracksPresenter(
            output: receiver,
            selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator()
        )
        output.configure(presenter: presenter)
        return LibraryTracksActionHandler(
            output: output,
            applyBatchFilenameRename: {}
        )
    }
}

@MainActor
private final class LibraryTracksStateReceiverSpy: LibraryTracksStateReceiving {
    private(set) var receivedState: LibraryTracksScreenState?

    func receive(_ state: LibraryTracksScreenState) {
        receivedState = state
    }
}

@MainActor
private final class LibraryTracksActionOutputSpy: LibraryTracksActionHandlingOutput {
    private(set) var loadIfNeededCallCount = 0
    private(set) var selectedSortModes: [LibraryTrackSortMode] = []
    private(set) var startSelectionCallCount = 0
    private(set) var cancelSelectionCallCount = 0
    private(set) var toggledTrackIDs: [UUID] = []
    private(set) var toggleSelectAllCallCount = 0
    private(set) var selectedBatchActions: [BulkTrackAction] = []
    private(set) var confirmBatchActionCallCount = 0
    private(set) var refreshCallCount = 0

    func loadTracksIfNeeded() async { loadIfNeededCallCount += 1 }
    func refreshTracks() async { refreshCallCount += 1 }
    func selectSortMode(_ mode: LibraryTrackSortMode) async { selectedSortModes.append(mode) }
    func startSelection() { startSelectionCallCount += 1 }
    func cancelSelection() { cancelSelectionCallCount += 1 }
    func toggleSelection(for trackId: UUID) { toggledTrackIDs.append(trackId) }
    func toggleSelectAll() { toggleSelectAllCallCount += 1 }
    func selectBatchAction(_ action: BulkTrackAction) { selectedBatchActions.append(action) }
    func confirmBatchAction() { confirmBatchActionCallCount += 1 }
}

/// Имитирует только screen-flow, чтобы проверить передачу действия в Presenter без фонотеки и файловой системы.
@MainActor
private final class LibraryTracksActionStateFlowSpy: LibraryTracksActionHandlingOutput {
    let selectedTrackID = UUID()
    private(set) var appliedPendingActions: [PendingBulkTrackActionExpectation] = []
    private var presenter: LibraryTracksPresenter?
    private var isLoading = false
    private var didLoad = false
    private var sortMode: LibraryTrackSortMode = .fileDateDesc
    private var selection = BulkSelectionState<UUID, BulkTrackAction>()

    /// Подключает реальный Presenter после инициализации, избегая сильного цикла в тестовом graph.
    func configure(presenter: LibraryTracksPresenter) {
        self.presenter = presenter
    }

    func loadTracksIfNeeded() async {
        didLoad = true
        isLoading = true
        presentState()
    }

    func refreshTracks() async {
        isLoading = true
        presentState()
    }

    func selectSortMode(_ mode: LibraryTrackSortMode) async {
        sortMode = mode
        presentState()
    }

    func startSelection() {
        selection.activate()
        presentState()
    }

    func cancelSelection() {
        selection.reset()
        presentState()
    }

    func toggleSelection(for trackId: UUID) {
        guard selection.isActive else { return }
        selection.selection.toggle(trackId)
        presentState()
    }

    func toggleSelectAll() {
        guard selection.isActive else { return }
        selection.selection.toggle(selectedTrackID)
        presentState()
    }

    func selectBatchAction(_ action: BulkTrackAction) {
        if selection.isActive {
            selection.setPendingAction(action)
            presentState()
            return
        }

        selection.activate(action: action)
        presentState()
    }

    func confirmBatchAction() {
        guard let action = selection.pendingAction else { return }
        apply(action)
    }

    /// Повторяет production-семантику: batch handler принимает упорядоченный снимок до reset.
    private func apply(_ action: BulkTrackAction) {
        guard selection.hasSelection else { return }

        appliedPendingActions.append(
            PendingBulkTrackActionExpectation(
                action: action,
                trackIDs: selection.selection.ids
            )
        )
        selection.reset()
        presentState()
    }

    /// Публикует снимок тем же API Presenter-а, который использует production ViewModel.
    private func presentState() {
        guard let presenter else {
            XCTFail("Presenter должен быть настроен до обработки action")
            return
        }

        presenter.present(
            presenter.makeState(
                sections: [],
                isLoading: isLoading,
                didLoad: didLoad,
                sortMode: sortMode,
                selection: selection,
                membershipsById: [:],
                isBatchFilenameRenameFlowActive: false
            )
        )
    }
}

/// Снимок вызова существующего batch handler-а, удобный для проверки порядка ID без SwiftUI.
private struct PendingBulkTrackActionExpectation: Equatable {
    let action: BulkTrackAction
    let trackIDs: [UUID]
}

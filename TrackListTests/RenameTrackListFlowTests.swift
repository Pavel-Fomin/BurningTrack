//
//  RenameTrackListFlowTests.swift
//  TrackList
//
//  Focused-проверки flow переименования треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет ViewModel и ActionHandler Rename TrackList через явные feature-зависимости.
@MainActor
final class RenameTrackListFlowTests: XCTestCase {

    func testInitialStateContainsCurrentName() {
        let (viewModel, _, _, _) = makeViewModel(currentName: "Текущий")

        XCTAssertEqual(viewModel.state.name, "Текущий")
        XCTAssertFalse(viewModel.state.canSubmit)
        XCTAssertFalse(viewModel.state.isSubmitting)
    }

    func testEmptyNameDoesNotAllowSubmit() {
        let (viewModel, _, _, _) = makeViewModel(currentName: "Текущий")

        viewModel.handle(.nameChanged(""))

        XCTAssertFalse(viewModel.state.canSubmit)
    }

    func testWhitespaceNameDoesNotAllowSubmit() {
        let (viewModel, _, _, _) = makeViewModel(currentName: "Текущий")

        viewModel.handle(.nameChanged(" \n "))

        XCTAssertFalse(viewModel.state.canSubmit)
    }

    func testNameMatchingCurrentAfterNormalizationDoesNotAllowSubmit() {
        let (viewModel, _, _, _) = makeViewModel(currentName: "Текущий")

        viewModel.handle(.nameChanged("  Текущий\n"))

        XCTAssertFalse(viewModel.state.canSubmit)
    }

    func testNewValidNameAllowsSubmit() {
        let (viewModel, _, _, _) = makeViewModel(currentName: "Текущий")

        viewModel.handle(.nameChanged("Новый"))

        XCTAssertTrue(viewModel.state.canSubmit)
    }

    func testNameChangedUpdatesState() {
        let (viewModel, _, _, _) = makeViewModel(currentName: "Текущий")

        viewModel.handle(.nameChanged("Вечерний"))

        XCTAssertEqual(viewModel.state.name, "Вечерний")
    }

    func testCancelClosesFlowThroughExplicitRouter() {
        let (viewModel, _, _, router) = makeViewModel(currentName: "Текущий")

        viewModel.handle(.cancel)

        XCTAssertEqual(router.closeCount, 1)
    }

    func testRepeatedSubmitIsIgnoredWhileCommandIsScheduled() async {
        let (viewModel, service, _, _) = makeViewModel(currentName: "Текущий")

        viewModel.handle(.nameChanged("Новый"))
        viewModel.handle(.submit)
        viewModel.handle(.submit)

        XCTAssertTrue(viewModel.state.isSubmitting)
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(service.renameRequests.count, 1)
    }

    func testSuccessfulRenameUsesNormalizedNameShowsToastAndClosesFlow() {
        let service = RenameTrackListServiceSpy()
        let toast = RenameTrackListToastSpy()
        let router = RenameTrackListRouterSpy()
        let handler = makeActionHandler(
            service: service,
            toast: toast,
            router: router
        )
        let trackListId = UUID()

        let result = handler.rename(
            trackListId: trackListId,
            newName: "  Новый  "
        )

        XCTAssertEqual(result, .success)
        XCTAssertEqual(service.renameRequests.count, 1)
        XCTAssertEqual(service.renameRequests.first?.id, trackListId)
        XCTAssertEqual(service.renameRequests.first?.name, "Новый")
        XCTAssertEqual(toast.events, [.trackListRenamed(newName: "Новый")])
        XCTAssertEqual(router.closeCount, 1)
    }

    func testRenameErrorShowsToastAndKeepsFlowOpen() {
        let service = RenameTrackListServiceSpy()
        service.renameError = AppError.trackListRenameNotAllowed
        let toast = RenameTrackListToastSpy()
        let router = RenameTrackListRouterSpy()
        let handler = makeActionHandler(
            service: service,
            toast: toast,
            router: router
        )

        let result = handler.rename(
            trackListId: UUID(),
            newName: "Новый"
        )

        XCTAssertEqual(result, .failure)
        XCTAssertEqual(router.closeCount, 0)
        XCTAssertEqual(toast.errors.count, 1)
        guard case .trackListRenameNotAllowed? = toast.errors.first else {
            return XCTFail("Должна быть показана ошибка невозможности переименования")
        }
    }

    private func makeViewModel(
        currentName: String
    ) -> (
        RenameTrackListViewModel,
        RenameTrackListServiceSpy,
        RenameTrackListToastSpy,
        RenameTrackListRouterSpy
    ) {
        let service = RenameTrackListServiceSpy()
        let toast = RenameTrackListToastSpy()
        let router = RenameTrackListRouterSpy()
        let actionHandler = makeActionHandler(
            service: service,
            toast: toast,
            router: router
        )
        let viewModel = RenameTrackListViewModel(
            trackListId: UUID(),
            currentName: currentName,
            stateBuilder: RenameTrackListStateBuilder(),
            actionHandler: actionHandler
        )

        return (viewModel, service, toast, router)
    }

    private func makeActionHandler(
        service: RenameTrackListServiceSpy,
        toast: RenameTrackListToastSpy,
        router: RenameTrackListRouterSpy
    ) -> RenameTrackListActionHandler {
        RenameTrackListActionHandler(
            trackListsService: service,
            toastPresenter: toast,
            router: router
        )
    }
}

/// Небольшой fake доменной зависимости для focused-тестов Rename TrackList.
@MainActor
private final class RenameTrackListServiceSpy: TrackListsManaging {
    var renameRequests: [(id: UUID, name: String)] = []
    var renameError: Error?

    func ensureFavoritesTrackList() throws -> TrackListMeta {
        throw AppError.trackListSaveFailed
    }

    func favoritesTrackList() throws -> TrackListMeta? {
        nil
    }

    func loadTrackListMetas() throws -> [TrackListMeta] {
        []
    }

    func deleteTrackList(id: UUID) throws {}

    func renameTrackList(id: UUID, to newName: String) throws {
        if let renameError {
            throw renameError
        }

        renameRequests.append((id: id, name: newName))
    }

    func updateTrackListsOrder(_ orderedIds: [UUID]) throws {}
}

/// Запоминает сообщения, переданные flow в presentation-слой.
@MainActor
private final class RenameTrackListToastSpy: ToastPresenting {
    var events: [ToastEvent] = []
    var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Проверяет typed-маршрутизацию Rename TrackList без зависимости от SheetManager.
@MainActor
private final class RenameTrackListRouterSpy: RenameTrackListRouting {
    var closeCount = 0

    func dismissRenameTrackList(_ routeID: UUID) {
        closeCount += 1
    }
}

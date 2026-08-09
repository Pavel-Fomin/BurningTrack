//
//  CreateTrackListFlowTests.swift
//  TrackList
//
//  Focused-проверки flow создания нового треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

/// Проверяет ViewModel и ActionHandler Create TrackList через явные feature-зависимости.
@MainActor
final class CreateTrackListFlowTests: XCTestCase {

    func testInitialStateUsesProvidedName() {
        let (viewModel, _, _, _) = makeViewModel(initialName: "Новый треклист")

        XCTAssertEqual(viewModel.state.name, "Новый треклист")
        XCTAssertTrue(viewModel.state.canSubmit)
    }

    func testEmptyNameDoesNotAllowCreation() {
        let (viewModel, manager, _, _) = makeViewModel(initialName: "Готовый")

        viewModel.handle(.nameChanged(" \n "))
        viewModel.handle(.createEmpty)

        XCTAssertFalse(viewModel.state.canSubmit)
        XCTAssertTrue(manager.createdEmptyNames.isEmpty)
    }

    func testValidNameAllowsCreation() {
        let (viewModel, _, _, _) = makeViewModel(initialName: "")

        viewModel.handle(.nameChanged("Road Trip"))

        XCTAssertEqual(viewModel.state.name, "Road Trip")
        XCTAssertTrue(viewModel.state.canSubmit)
    }

    func testCreateEmptyInvokesDomainCommandWithTrimmedName() {
        let (viewModel, manager, toast, router) = makeViewModel(initialName: "  Morning  ")

        viewModel.handle(.createEmpty)

        XCTAssertEqual(manager.createdEmptyNames, ["Morning"])
        XCTAssertEqual(toast.events, [.trackListCreated(name: "Morning")])
        XCTAssertEqual(router.closeCount, 1)
    }

    func testAddTracksRoutesToSelectionWithTrimmedName() {
        let (viewModel, _, _, router) = makeViewModel(initialName: "  Set  ")

        viewModel.handle(.addTracks)

        XCTAssertEqual(router.selectionNames, ["Set"])
        XCTAssertEqual(router.closeCount, 0)
    }

    func testCancelClosesCreateSheet() {
        let (viewModel, _, _, router) = makeViewModel(initialName: "Set")

        viewModel.handle(.cancel)

        XCTAssertEqual(router.closeCount, 1)
    }

    func testDomainErrorShowsToastAndKeepsFlowOpen() {
        let manager = CreateTrackListManagerSpy()
        manager.createEmptyError = AppError.trackListSaveFailed
        let toast = CreateTrackListToastSpy()
        let router = CreateTrackListRouterSpy()
        let (viewModel, _, _, _) = makeViewModel(
            initialName: "Set",
            manager: manager,
            toast: toast,
            router: router
        )

        viewModel.handle(.createEmpty)

        XCTAssertEqual(router.closeCount, 0)
        XCTAssertEqual(toast.errors.count, 1)
        guard case .trackListSaveFailed? = toast.errors.first else {
            return XCTFail("Должна быть показана ошибка сохранения треклиста")
        }
    }

    private func makeViewModel(
        initialName: String
    ) -> (
        CreateTrackListViewModel,
        CreateTrackListManagerSpy,
        CreateTrackListToastSpy,
        CreateTrackListRouterSpy
    ) {
        makeViewModel(
            initialName: initialName,
            manager: CreateTrackListManagerSpy(),
            toast: CreateTrackListToastSpy(),
            router: CreateTrackListRouterSpy()
        )
    }

    private func makeViewModel(
        initialName: String,
        manager: CreateTrackListManagerSpy,
        toast: CreateTrackListToastSpy,
        router: CreateTrackListRouterSpy
    ) -> (
        CreateTrackListViewModel,
        CreateTrackListManagerSpy,
        CreateTrackListToastSpy,
        CreateTrackListRouterSpy
    ) {
        let actionHandler = CreateTrackListActionHandler(
            trackListsManager: manager,
            toastPresenter: toast,
            router: router
        )
        let viewModel = CreateTrackListViewModel(
            initialName: initialName,
            stateBuilder: CreateTrackListStateBuilder(),
            actionHandler: actionHandler
        )

        return (viewModel, manager, toast, router)
    }
}

/// Небольшой fake доменной зависимости для focused-тестов Create TrackList.
@MainActor
private final class CreateTrackListManagerSpy: TrackListFlowManaging {
    var createdEmptyNames: [String] = []
    var createEmptyError: Error?

    func createEmptyTrackList(withName name: String) throws -> TrackList {
        if let createEmptyError {
            throw createEmptyError
        }

        createdEmptyNames.append(name)
        return makeTrackList(name: name)
    }

    func createTrackList(
        from libraryTracks: [LibraryTrack],
        withName name: String
    ) throws -> TrackList {
        makeTrackList(name: name)
    }

    func loadTrackListMetas() throws -> [TrackListMeta] {
        []
    }

    func addTracks(
        _ libraryTracks: [LibraryTrack],
        to trackListId: UUID
    ) throws -> Bool {
        true
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

/// Запоминает сообщения, переданные flow в presentation-слой.
@MainActor
private final class CreateTrackListToastSpy: ToastPresenting {
    var events: [ToastEvent] = []
    var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Проверяет typed-маршрутизацию Create TrackList без зависимости от SheetManager.
@MainActor
private final class CreateTrackListRouterSpy: CreateTrackListRouting {
    var closeCount = 0
    var selectionNames: [String] = []

    func dismissCreateTrackList(_ routeID: UUID) {
        closeCount += 1
    }

    func presentTrackSelectionForCreate(name: String, from routeID: UUID) {
        selectionNames.append(name)
    }
}

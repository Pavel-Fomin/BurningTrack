//
// "LibraryCollectionValuesViewModelTests.swift"
// TrackList
// Проверяет typed actions и сохранение результата загрузки значений коллекции.
// Created by Pavel Fomin on 13.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class LibraryCollectionValuesViewModelTests: XCTestCase {
    func testScreenAppearedLoadsOnceAndSortsCachedValues() async {
        let provider = CollectionValuesProviderSpy(values: [
            makeValue(id: "z", title: "Zulu"),
            makeValue(id: "a", title: "Alpha")
        ])
        let viewModel = makeViewModel(
            category: .artists,
            provider: provider
        )
        let loadExpectation = expectation(description: "Значения загружены")
        provider.onValuesRequested = {
            loadExpectation.fulfill()
        }

        viewModel.send(.screenAppeared)
        await fulfillment(of: [loadExpectation], timeout: 1)
        viewModel.send(.screenAppeared)
        await Task.yield()

        XCTAssertEqual(provider.loadCount, 1)
        XCTAssertEqual(viewModel.state.values.map(\.title), ["Alpha", "Zulu"])
        XCTAssertEqual(viewModel.state.sortMode, .titleAscending)

        viewModel.send(.sortModeSelected(.titleDescending))

        XCTAssertEqual(provider.loadCount, 1)
        XCTAssertEqual(viewModel.state.values.map(\.title), ["Zulu", "Alpha"])
        XCTAssertEqual(viewModel.state.sortMode, .titleDescending)
    }

    func testInitialScreenStateContainsCategoryLoadingValuesAndSortMode() {
        let viewModel = makeViewModel(
            category: .years,
            provider: CollectionValuesProviderSpy(values: [])
        )

        XCTAssertEqual(viewModel.state.category, .years)
        XCTAssertTrue(viewModel.state.isLoading)
        XCTAssertTrue(viewModel.state.values.isEmpty)
        XCTAssertEqual(viewModel.state.sortMode, .yearNewestFirst)
    }

    func testInvalidAndRepeatedSortActionsDoNotChangeLoadedState() async {
        let provider = CollectionValuesProviderSpy(values: [
            makeValue(id: "a", title: "Alpha"),
            makeValue(id: "z", title: "Zulu")
        ])
        let viewModel = makeViewModel(category: .artists, provider: provider)
        let loadExpectation = expectation(description: "Значения загружены")
        provider.onValuesRequested = {
            loadExpectation.fulfill()
        }

        viewModel.send(.screenAppeared)
        await fulfillment(of: [loadExpectation], timeout: 1)
        let loadedState = viewModel.state

        viewModel.send(.sortModeSelected(.yearNewestFirst))
        XCTAssertEqual(viewModel.state, loadedState)

        viewModel.send(.sortModeSelected(.titleAscending))
        XCTAssertEqual(viewModel.state, loadedState)
        XCTAssertEqual(provider.loadCount, 1)
    }

    func testAlbumSortActionPreservesAlbumSpecificModes() async {
        let provider = CollectionValuesProviderSpy(values: [
            makeValue(id: "older", title: "Older", category: .albums, year: 1999),
            makeValue(id: "newer", title: "Newer", category: .albums, year: 2024)
        ])
        let viewModel = makeViewModel(category: .albums, provider: provider)
        let loadExpectation = expectation(description: "Значения загружены")
        provider.onValuesRequested = {
            loadExpectation.fulfill()
        }

        viewModel.send(.screenAppeared)
        await fulfillment(of: [loadExpectation], timeout: 1)
        viewModel.send(.sortModeSelected(.yearNewestFirst))

        XCTAssertEqual(viewModel.state.sortMode, .yearNewestFirst)
        XCTAssertEqual(viewModel.state.values.map(\.title), ["Newer", "Older"])
        XCTAssertEqual(provider.loadCount, 1)
    }

    func testCancelledLoadDoesNotPublishLateProviderResult() async {
        let loadExpectation = expectation(description: "Provider начал чтение")
        let provider = SuspendedCollectionValuesProvider(
            onValuesRequested: {
                loadExpectation.fulfill()
            }
        )
        let viewModel = makeViewModel(category: .artists, provider: provider)

        let task = Task {
            await viewModel.loadValuesIfNeeded()
        }
        await fulfillment(of: [loadExpectation], timeout: 1)
        task.cancel()
        provider.resume(with: [makeValue(id: "late", title: "Late")])
        await task.value

        XCTAssertTrue(viewModel.state.isLoading)
        XCTAssertTrue(viewModel.state.values.isEmpty)
    }

    private func makeViewModel(
        category: LibraryCollectionCategory,
        provider: LibraryCollectionValuesProvider
    ) -> LibraryCollectionValuesViewModel {
        let viewModel = LibraryCollectionValuesViewModel(
            category: category,
            provider: provider
        )
        let actionHandler = LibraryCollectionValuesActionHandler(output: viewModel)
        viewModel.configure(actionHandler: actionHandler)
        return viewModel
    }

    private func makeValue(
        id: String,
        title: String,
        category: LibraryCollectionCategory = .artists,
        year: Int? = nil
    ) -> LibraryCollectionValue {
        LibraryCollectionValue(
            id: id,
            category: category,
            title: title,
            rawValue: title,
            tracksCount: 1,
            year: year
        )
    }
}

/// Возвращает фиксированные значения и фиксирует число обращений ViewModel к provider.
@MainActor
private final class CollectionValuesProviderSpy: LibraryCollectionValuesProvider {
    private let loadedValues: [LibraryCollectionValue]
    private(set) var loadCount = 0
    var onValuesRequested: (() -> Void)?

    init(values: [LibraryCollectionValue]) {
        loadedValues = values
    }

    func values(for category: LibraryCollectionCategory) async -> [LibraryCollectionValue] {
        loadCount += 1
        onValuesRequested?()
        return loadedValues
    }
}

/// Удерживает provider до отмены, чтобы проверить защиту от позднего async-результата.
@MainActor
private final class SuspendedCollectionValuesProvider: LibraryCollectionValuesProvider {
    private var continuation: CheckedContinuation<[LibraryCollectionValue], Never>?
    private let onValuesRequested: () -> Void

    init(onValuesRequested: @escaping () -> Void) {
        self.onValuesRequested = onValuesRequested
    }

    func values(for _: LibraryCollectionCategory) async -> [LibraryCollectionValue] {
        onValuesRequested()

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume(with values: [LibraryCollectionValue]) {
        continuation?.resume(returning: values)
        continuation = nil
    }
}

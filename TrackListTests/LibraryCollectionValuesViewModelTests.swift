//
// "LibraryCollectionValuesViewModelTests.swift"
// TrackList
// Проверяет injected provider и сохранение результата загрузки значений коллекции.
// Created by Pavel Fomin on 13.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class LibraryCollectionValuesViewModelTests: XCTestCase {
    func testInjectedProviderLoadsOnceAndSortsCachedValues() async {
        let provider = CollectionValuesProviderSpy(values: [
            makeValue(id: "z", title: "Zulu"),
            makeValue(id: "a", title: "Alpha")
        ])
        let viewModel = LibraryCollectionValuesViewModel(
            category: .artists,
            provider: provider
        )

        await viewModel.load()
        await viewModel.load()

        XCTAssertEqual(provider.loadCount, 1)
        XCTAssertEqual(viewModel.state.values.map(\.title), ["Alpha", "Zulu"])

        viewModel.setSortMode(.titleDescending)

        XCTAssertEqual(provider.loadCount, 1)
        XCTAssertEqual(viewModel.state.values.map(\.title), ["Zulu", "Alpha"])
    }

    private func makeValue(id: String, title: String) -> LibraryCollectionValue {
        LibraryCollectionValue(
            id: id,
            category: .artists,
            title: title,
            rawValue: title,
            tracksCount: 1
        )
    }
}

/// Возвращает фиксированные значения и фиксирует число обращений ViewModel к provider.
@MainActor
private final class CollectionValuesProviderSpy: LibraryCollectionValuesProvider {
    private let loadedValues: [LibraryCollectionValue]
    private(set) var loadCount = 0

    init(values: [LibraryCollectionValue]) {
        loadedValues = values
    }

    func values(for category: LibraryCollectionCategory) async -> [LibraryCollectionValue] {
        loadCount += 1
        return loadedValues
    }
}

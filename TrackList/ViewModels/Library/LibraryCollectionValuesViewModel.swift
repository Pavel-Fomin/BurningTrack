//
//  LibraryCollectionValuesViewModel.swift
//  TrackList
//
//  ViewModel экрана значений раздела музыкальной коллекции.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

struct LibraryCollectionValuesScreenState {
    /// Раздел коллекции, значения которого отображаются.
    let category: LibraryCollectionCategory
    /// Показывает, что значения сейчас загружаются из SQLite metadata.
    let isLoading: Bool
    /// Загруженные значения раздела.
    let values: [LibraryCollectionValue]

    /// Пустое состояние после завершения загрузки.
    var isEmpty: Bool {
        isLoading == false && values.isEmpty
    }
}

@MainActor
final class LibraryCollectionValuesViewModel: ObservableObject {
    // MARK: - Output

    /// Готовое состояние экрана для SwiftUI.
    @Published private(set) var state: LibraryCollectionValuesScreenState

    // MARK: - Dependencies

    private let category: LibraryCollectionCategory
    private let provider: LibraryCollectionValuesProvider

    // MARK: - Private

    private var didLoad = false

    // MARK: - Init

    init(
        category: LibraryCollectionCategory,
        provider: LibraryCollectionValuesProvider = DefaultLibraryCollectionValuesProvider()
    ) {
        self.category = category
        self.provider = provider
        self.state = LibraryCollectionValuesScreenState(
            category: category,
            isLoading: true,
            values: []
        )
    }

    // MARK: - Actions

    /// Загружает значения выбранного раздела один раз за жизненный цикл экрана.
    func load() async {
        guard didLoad == false else { return }
        didLoad = true

        state = LibraryCollectionValuesScreenState(
            category: category,
            isLoading: true,
            values: []
        )

        let values = await provider.values(for: category)
        guard Task.isCancelled == false else { return }

        state = LibraryCollectionValuesScreenState(
            category: category,
            isLoading: false,
            values: values
        )
    }
}

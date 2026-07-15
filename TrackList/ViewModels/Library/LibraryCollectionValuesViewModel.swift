//
//  LibraryCollectionValuesViewModel.swift
//  TrackList
//
//  ViewModel экрана значений раздела музыкальной коллекции.
//
//  Created by Pavel Fomin on 09.07.2026.
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
    /// Текущий режим сортировки значений в рамках жизненного цикла экрана.
    @Published private(set) var sortMode: LibraryCollectionValueSortMode

    // MARK: - Dependencies

    private let category: LibraryCollectionCategory
    private let provider: LibraryCollectionValuesProvider

    // MARK: - Private

    private var didLoad = false
    /// Исходные значения после чтения provider, чтобы менять порядок без повторного чтения SQLite.
    private var loadedValues: [LibraryCollectionValue] = []

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
        self.sortMode = category.defaultValueSortMode
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

        loadedValues = values
        state = LibraryCollectionValuesScreenState(
            category: category,
            isLoading: false,
            values: sortedValues()
        )
    }

    /// Меняет сортировку уже загруженных значений без повторного обращения к provider.
    func setSortMode(_ mode: LibraryCollectionValueSortMode) {
        guard category.availableValueSortModes.contains(mode) else { return }
        guard sortMode != mode else { return }

        sortMode = mode
        state = LibraryCollectionValuesScreenState(
            category: category,
            isLoading: state.isLoading,
            values: sortedValues()
        )
    }

    // MARK: - Private

    /// Сортирует только сохранённый в памяти результат provider.
    private func sortedValues() -> [LibraryCollectionValue] {
        LibraryCollectionValueSorter.sort(loadedValues, mode: sortMode)
    }
}

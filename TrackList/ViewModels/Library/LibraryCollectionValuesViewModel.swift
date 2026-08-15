//
//  LibraryCollectionValuesViewModel.swift
//  TrackList
//
//  ViewModel экрана значений раздела музыкальной коллекции.
//
//  Created by Pavel Fomin on 09.07.2026.
//

import Foundation

struct LibraryCollectionValuesScreenState: Equatable {
    /// Раздел коллекции, значения которого отображаются.
    let category: LibraryCollectionCategory
    /// Показывает, что значения сейчас загружаются из SQLite metadata.
    let isLoading: Bool
    /// Загруженные значения раздела.
    let values: [LibraryCollectionValue]
    /// Текущий режим сортировки уже загруженного снимка значений.
    let sortMode: LibraryCollectionValueSortMode

    /// Пустое состояние после завершения загрузки.
    var isEmpty: Bool {
        isLoading == false && values.isEmpty
    }
}

@MainActor
final class LibraryCollectionValuesViewModel: ObservableObject, LibraryCollectionValuesActionOutput {
    // MARK: - Выходные данные

    /// Готовое состояние экрана для SwiftUI.
    @Published private(set) var state: LibraryCollectionValuesScreenState
    // MARK: - Зависимости

    private let category: LibraryCollectionCategory
    private let provider: LibraryCollectionValuesProvider
    /// Handler сохраняет typed flow пользовательских действий вне SwiftUI View.
    private var actionHandler: LibraryCollectionValuesActionHandler?

    // MARK: - Приватное

    private var didLoad = false
    /// Исходные значения после чтения provider, чтобы менять порядок без повторного чтения SQLite.
    private var loadedValues: [LibraryCollectionValue] = []

    // MARK: - Инициализация

    init(
        category: LibraryCollectionCategory,
        provider: LibraryCollectionValuesProvider
    ) {
        self.category = category
        self.provider = provider
        self.state = LibraryCollectionValuesScreenState(
            category: category,
            isLoading: true,
            values: [],
            sortMode: category.defaultValueSortMode
        )
    }

    // MARK: - Действия

    /// Подключает handler после того, как ViewModel стала его слабым output.
    func configure(actionHandler: LibraryCollectionValuesActionHandler) {
        self.actionHandler = actionHandler
    }

    /// Принимает typed intent View и не раскрывает ей загрузку или сортировку напрямую.
    func send(_ action: LibraryCollectionValuesAction) {
        actionHandler?.handle(action)
    }

    /// Загружает значения выбранного раздела один раз за жизненный цикл экрана.
    func loadValuesIfNeeded() async {
        guard didLoad == false else { return }
        didLoad = true

        state = LibraryCollectionValuesScreenState(
            category: category,
            isLoading: true,
            values: [],
            sortMode: state.sortMode
        )

        let values = await provider.values(for: category)
        guard Task.isCancelled == false else { return }

        loadedValues = values
        state = LibraryCollectionValuesScreenState(
            category: category,
            isLoading: false,
            values: sortedValues(),
            sortMode: state.sortMode
        )
    }

    /// Меняет сортировку уже загруженных значений без повторного обращения к provider.
    func selectSortMode(_ mode: LibraryCollectionValueSortMode) {
        guard category.availableValueSortModes.contains(mode) else { return }
        guard state.sortMode != mode else { return }

        state = LibraryCollectionValuesScreenState(
            category: category,
            isLoading: state.isLoading,
            values: sortedValues(mode: mode),
            sortMode: mode
        )
    }

    // MARK: - Приватное

    /// Сортирует только сохранённый в памяти результат provider.
    private func sortedValues(
        mode: LibraryCollectionValueSortMode? = nil
    ) -> [LibraryCollectionValue] {
        LibraryCollectionValueSorter.sort(
            loadedValues,
            mode: mode ?? state.sortMode
        )
    }
}

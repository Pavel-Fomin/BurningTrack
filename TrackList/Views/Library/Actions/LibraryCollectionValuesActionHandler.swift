//
//  LibraryCollectionValuesActionHandler.swift
//  TrackList
//
//  Обрабатывает typed действия экрана значений музыкальной коллекции.
//
//  Created by Pavel Fomin on 14.08.2026.
//

import Foundation

/// Маршрутизирует действия View к semantic API ViewModel без SQLite-доступа из SwiftUI.
@MainActor
final class LibraryCollectionValuesActionHandler {
    /// Слабый output исключает цикл между ViewModel и ActionHandler.
    private weak var output: (any LibraryCollectionValuesActionOutput)?

    init(output: any LibraryCollectionValuesActionOutput) {
        self.output = output
    }

    /// Обрабатывает lifecycle и выбор сортировки одного destination.
    func handle(_ action: LibraryCollectionValuesAction) {
        switch action {
        case .screenAppeared:
            loadValuesIfNeeded()
        case .sortModeSelected(let mode):
            output?.selectSortMode(mode)
        }
    }

    /// Запускает чтение у ViewModel, сохраняя View свободной от async domain-вызова.
    private func loadValuesIfNeeded() {
        Task { [weak self] in
            await self?.output?.loadValuesIfNeeded()
        }
    }
}

/// Узкий контракт output оставляет семантику данных и screen-state у ViewModel.
@MainActor
protocol LibraryCollectionValuesActionOutput: AnyObject {
    func loadValuesIfNeeded() async
    func selectSortMode(_ mode: LibraryCollectionValueSortMode)
}

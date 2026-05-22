//
//  OrderedSelection.swift
//  TrackList
//
//  Упорядоченное состояние выбранных элементов.
//
//  Роль:
//  - хранит выбранные ID в порядке выбора;
//  - не использует Set, потому что порядок важен для batch-действий;
//  - не знает ничего о треках, файлах или конкретных экранах.
//
//  Created by Pavel Fomin on 19.05.2026.
//


import Foundation

struct OrderedSelection<ID: Hashable> {
    /// ID выбранных элементов в порядке выбора.
    private(set) var ids: [ID] = []

    /// Количество выбранных элементов.
    var count: Int {
        ids.count
    }

    /// Показывает, пустой ли выбор.
    var isEmpty: Bool {
        ids.isEmpty
    }

    /// Переключает выбор элемента.
    mutating func toggle(_ id: ID) {
        if ids.contains(id) {
            ids.removeAll { $0 == id }
        } else {
            ids.append(id)
        }
    }

    /// Полностью очищает выбор.
    mutating func clear() {
        ids.removeAll()
    }

    /// Полностью заменяет выбор переданным списком ID, сохраняя порядок.
    mutating func replace(with ids: [ID]) {
        self.ids = ids
    }

    /// Проверяет, выбран ли элемент.
    func contains(_ id: ID) -> Bool {
        ids.contains(id)
    }
}

//
//  BulkSelectionState.swift
//  TrackList
//
//  Состояние массового выбора элементов.
//
//  Роль:
//  - хранит активность режима выбора;
//  - хранит выбранные ID в стабильном порядке;
//  - хранит действие, которое ожидает подтверждения через action bar;
//  - не знает ничего о треках, файлах или конкретном экране.
//
//  Created by Pavel Fomin on 21.05.2026.
//

import Foundation

struct BulkSelectionState<ID: Hashable, Action> {
    /// Показывает, активен ли режим массового выбора.
    private(set) var isActive = false

    /// ID выбранных элементов в порядке выбора.
    var selection = OrderedSelection<ID>()

    /// Действие, ожидающее выбора элементов и подтверждения.
    private(set) var pendingAction: Action?

    /// Количество выбранных элементов.
    var selectedCount: Int {
        selection.count
    }

    /// Показывает, есть ли выбранные элементы.
    var hasSelection: Bool {
        !selection.isEmpty
    }

    /// Включает выбор без заранее выбранного действия.
    mutating func activate() {
        isActive = true
        pendingAction = nil
    }

    /// Включает выбор и запоминает действие, которое будет подтверждено позже.
    mutating func activate(action: Action) {
        isActive = true
        pendingAction = action
    }

    /// Меняет ожидающее действие без сброса текущего выбора.
    mutating func setPendingAction(_ action: Action) {
        isActive = true
        pendingAction = action
    }

    /// Заменяет текущий выбор переданным списком ID.
    mutating func replaceSelection(with ids: [ID]) {
        selection.replace(with: ids)
    }

    /// Полностью очищает выбор и выходит из режима массового выбора.
    mutating func reset() {
        isActive = false
        pendingAction = nil
        selection.clear()
    }
}

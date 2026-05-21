//
//  MultiselectMode.swift
//  TrackList
//
//  Общая модель режима мультиселекта.
//
//  Роль:
//  - описывает, находится ли список в обычном режиме;
//  - хранит выбранное batch-действие, если пользователь вошёл в выбор через меню;
//  - не знает ничего о конкретном экране, треках или файлах.
//
//  Created by Pavel Fomin on 19.05.2026.
//


import Foundation

enum MultiselectMode<Action> {
    /// Обычный режим списка.
    case inactive

    /// Режим выбора элементов.
    /// Если action == nil, пользователь вошёл через кнопку "Выбрать".
    /// Если action != nil, пользователь вошёл через конкретное действие меню.
    case selecting(action: Action?)
}

extension MultiselectMode {
    /// Показывает, находится ли список в режиме выбора.
    var isSelecting: Bool {
        if case .selecting = self { return true }
        return false
    }

    /// Текущее выбранное действие, если оно было задано до выбора элементов.
    var action: Action? {
        if case .selecting(let action) = self { return action }
        return nil
    }
}

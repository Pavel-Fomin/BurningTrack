//
//  BatchTagFieldEditAction.swift
//  TrackList
//
//  Действие, выбранное для конкретного поля тега.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

enum BatchTagFieldEditAction: Equatable {
    case keep  /// Не менять это поле у выбранных треков.
    case set   /// Установить новое значение.
    case clear /// Очистить значение.
}

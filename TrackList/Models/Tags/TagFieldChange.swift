//
//  TagFieldChange.swift
//  TrackList
//
//  Универсальная модель изменения тега.
//
//  Семантика:
//  - unchanged → не менять поле
//  - set(value) → установить значение
//  - clear → очистить поле
//
//  Created by PavelFomin on 19.04.2026.
//

import Foundation

enum TagFieldChange<Value: Sendable & Equatable>: Sendable, Equatable {

    /// Поле не изменялось
    case unchanged

    /// Установить новое значение
    case set(Value)

    /// Очистить поле
    case clear
}

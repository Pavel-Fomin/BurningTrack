//
//  TrackListKind.swift
//  TrackList
//
//  Тип назначения треклиста.
//
//  Created by Pavel Fomin on 29.07.2026.
//

import Foundation

/// Определяет назначение треклиста в бизнес-модели приложения.
enum TrackListKind: Equatable {
    /// Обычный треклист, созданный пользователем.
    case regular

    /// Единственный системный треклист «Избранное».
    /// Его нельзя определять по названию, так как название локализуется и может изменяться.
    case favorites

    /// Разрешено ли переименовывать треклист данного назначения.
    var canRename: Bool {
        switch self {
        case .regular:
            return true
        case .favorites:
            return false
        }
    }

    /// Разрешено ли удалять треклист данного назначения.
    var canDelete: Bool {
        switch self {
        case .regular:
            return true
        case .favorites:
            return false
        }
    }

    /// Разрешено ли изменять пользовательский порядок треклистов данного назначения.
    var canReorder: Bool {
        switch self {
        case .regular:
            return true
        case .favorites:
            return false
        }
    }
}

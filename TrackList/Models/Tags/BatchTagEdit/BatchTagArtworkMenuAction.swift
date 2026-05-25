//
//  BatchTagArtworkMenuAction.swift
//  TrackList
//
//  Действие из меню карточки обложки.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

/// Действие из меню карточки обложки.
enum BatchTagArtworkMenuAction: Equatable {
    /// Удалить обложку.
    case remove
    /// Заменить обложку.
    case replace
    /// Сжать обложку.
    case compress
}

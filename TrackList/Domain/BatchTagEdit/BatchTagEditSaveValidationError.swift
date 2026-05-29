//
//  BatchTagEditSaveValidationError.swift
//  TrackList
//
//  Ошибка подготовки массового сохранения тегов.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// Ошибка подготовки массового сохранения тегов.
enum BatchTagEditSaveValidationError: Error, Equatable {
    /// Некорректное значение года.
    case invalidYear(String)
    /// Для замены обложки не выбраны данные новой обложки.
    case missingReplacementArtwork
}

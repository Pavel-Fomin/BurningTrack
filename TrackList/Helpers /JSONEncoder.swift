//
//  JSONEncoder.swift
//  TrackList
//
//  Утилита для человекочитаемого формата json
//
//  Created by Pavel Fomin on 25.07.2025.
//

import Foundation

/// Возвращает JSONEncoder с форматированием, удобным для чтения:
/// - отступы
/// - без экранирования слэшей (\/ → /)
func makePrettyJSONEncoder() -> JSONEncoder {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
    return encoder
}

//
//  FavoritesChangeEvent.swift
//  TrackList
//
//  Типизированное событие изменения состояния трека в «Избранном».
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Сообщает только логическую идентичность трека и его итоговое состояние в «Избранном».
struct FavoritesChangeEvent: Equatable, Sendable {

    /// Идентификатор исходного трека, а не идентификатор строки треклиста.
    let trackId: UUID
    /// Итоговое булево состояние трека после успешно сохранённого изменения.
    let isFavorite: Bool
}

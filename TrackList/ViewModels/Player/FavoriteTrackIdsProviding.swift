//
//  FavoriteTrackIdsProviding.swift
//  TrackList
//
//  Published-состояние идентификаторов избранных треков.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Combine
import Foundation

/// Предоставляет единый снимок «Избранного» и поток его точечных изменений для presentation-слоя.
@MainActor
protocol FavoriteTrackIdsProviding: AnyObject {
    /// Текущий подтверждённый набор идентификаторов треков в «Избранном».
    var favoriteTrackIds: Set<UUID> { get }
    /// Поток изменений подтверждённого набора без отдельной подписки на доменные события в экранах.
    var favoriteTrackIdsPublisher: AnyPublisher<Set<UUID>, Never> { get }
}

extension PlayerViewModel: FavoriteTrackIdsProviding {
    /// Публикует изменения единого состояния «Избранного» для state builders экранов.
    var favoriteTrackIdsPublisher: AnyPublisher<Set<UUID>, Never> {
        $favoriteTrackIds.eraseToAnyPublisher()
    }
}

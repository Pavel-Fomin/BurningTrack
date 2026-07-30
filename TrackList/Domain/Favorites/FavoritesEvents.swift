//
//  FavoritesEvents.swift
//  TrackList
//
//  Контракты публикации и наблюдения за изменениями «Избранного».
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Combine
import Foundation

/// Публикует типизированное изменение состояния одного трека в «Избранном».
protocol FavoritesEventsPublishing: AnyObject {

    /// Передаёт событие после успешного изменения сохранённого состояния.
    func publish(_ event: FavoritesChangeEvent)
}

/// Предоставляет поток типизированных изменений состояния «Избранного».
protocol FavoritesEventsObserving: AnyObject {

    /// События, появившиеся после подписки; начальное состояние не реплицируется.
    var events: AnyPublisher<FavoritesChangeEvent, Never> { get }
}

/// Объединяет публикацию и наблюдение для единого центра событий приложения.
typealias FavoritesEvents = FavoritesEventsPublishing & FavoritesEventsObserving

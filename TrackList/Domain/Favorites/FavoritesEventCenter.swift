//
//  FavoritesEventCenter.swift
//  TrackList
//
//  Единый транспорт событий изменения состояния «Избранного».
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Combine
import Foundation

/// Передаёт изменения Favorites через принятый в приложении NotificationCenter, не храня их состояние.
final class FavoritesEventCenter: FavoritesEvents {

    /// Общий экземпляр на весь жизненный цикл приложения.
    static let shared = FavoritesEventCenter()

    private let notificationCenter: NotificationCenter

    /// Создаёт центр событий с явным NotificationCenter для рабочей композиции и тестов.
    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    /// Преобразует инфраструктурное уведомление в типизированный поток для будущих подписчиков.
    var events: AnyPublisher<FavoritesChangeEvent, Never> {
        notificationCenter.publisher(for: .favoritesDidChange)
            .compactMap { $0.object as? FavoritesChangeEvent }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    /// Публикует типизированное событие без userInfo и без кэширования полного состояния Favorites.
    func publish(_ event: FavoritesChangeEvent) {
        notificationCenter.post(
            name: .favoritesDidChange,
            object: event
        )
    }
}

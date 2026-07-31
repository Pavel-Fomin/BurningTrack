//
//  FavoriteTrackActionHandler.swift
//  TrackList
//
//  Передаёт переключение «Избранного» в общий доменный сервис.
//
//  Created by Pavel Fomin on 01.08.2026.
//

import Foundation

/// Выполняет переключение «Избранного» через единственный доменный сервис без оптимистического UI-состояния.
@MainActor
struct FavoriteTrackActionHandler {

    /// Общий сервис хранит состояние в существующем системном треклисте и публикует подтверждённое изменение.
    private let favoritesService: any FavoritesServicing

    /// Создаёт обработчик с production-сервисом или явной зависимостью для изолированных сценариев.
    init(
        favoritesService: (any FavoritesServicing)? = nil
    ) {
        self.favoritesService = favoritesService ?? FavoritesService()
    }

    /// Передаёт переключение в доменный сервис и оставляет обновление интерфейса его событию.
    func toggle(_ track: FavoriteTrackInput) {
        do {
            _ = try favoritesService.toggle(track)
        } catch {
            // До успешной записи ViewModel не меняют published-состояние самостоятельно.
            PersistentLogger.log(
                "FavoriteTrackActionHandler: ошибка переключения избранного trackId=\(track.trackId) error=\(error)"
            )
        }
    }
}

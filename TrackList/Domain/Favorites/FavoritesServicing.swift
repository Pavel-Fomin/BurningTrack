//
//  FavoritesServicing.swift
//  TrackList
//
//  Контракт доменного сервиса системного треклиста «Избранное».
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Предоставляет булево состояние и идемпотентные операции для системного треклиста «Избранное».
@MainActor
protocol FavoritesServicing {

    /// Загружает все логические идентификаторы треков системного треклиста одним чтением.
    func loadFavoriteTrackIds() throws -> Set<UUID>

    /// Проверяет наличие логического идентификатора трека в системном треклисте.
    func isFavorite(trackId: UUID) throws -> Bool

    /// Добавляет трек в «Избранное», если его там ещё нет.
    @discardableResult
    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult

    /// Удаляет все вхождения трека из «Избранного».
    @discardableResult
    func remove(trackId: UUID) throws -> FavoritesMutationResult

    /// Переключает наличие трека в «Избранном» одним решением внутри сервиса.
    @discardableResult
    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult
}

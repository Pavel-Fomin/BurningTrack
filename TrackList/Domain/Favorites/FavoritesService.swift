//
//  FavoritesService.swift
//  TrackList
//
//  Доменный сервис работы с содержимым системного треклиста «Избранное».
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Управляет только содержимым системного треклиста, не завися от представления или SQLite-запросов.
@MainActor
final class FavoritesService: FavoritesServicing {

    private let trackListsManager: TrackListsManaging
    private let trackListManager: TrackListManaging
    /// Публикует результат собственной мутации, не заставляя ViewModel знать о сохранении.
    private let favoritesEvents: any FavoritesEventsPublishing

    /// Создаёт сервис с явными зависимостями для изолированных сценариев и тестов.
    init(
        trackListsManager: TrackListsManaging,
        trackListManager: TrackListManaging,
        favoritesEvents: any FavoritesEventsPublishing
    ) {
        self.trackListsManager = trackListsManager
        self.trackListManager = trackListManager
        self.favoritesEvents = favoritesEvents
    }

    /// Возвращает множество логических идентификаторов системного треклиста без дублирующих listItemId.
    func loadFavoriteTrackIds() throws -> Set<UUID> {
        let favorites = try resolvedFavoritesTrackList()
        let tracks = try trackListManager.loadTracks(for: favorites.id)

        return Set(tracks.map(\.trackId))
    }

    /// Возвращает true, если в системном треклисте есть хотя бы одна строка с переданным trackId.
    func isFavorite(trackId: UUID) throws -> Bool {
        let favorites = try resolvedFavoritesTrackList()
        let tracks = try trackListManager.loadTracks(for: favorites.id)

        return tracks.contains { $0.trackId == trackId }
    }

    /// Добавляет новую строку в конец «Избранного» только при отсутствии этого логического trackId.
    @discardableResult
    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        let favorites = try resolvedFavoritesTrackList()
        let tracks = try trackListManager.loadTracks(for: favorites.id)

        guard tracks.contains(where: { $0.trackId == track.trackId }) == false else {
            return .unchanged(isFavorite: true)
        }

        var updatedTracks = tracks
        updatedTracks.append(track.makeTrackListTrack())
        try save(updatedTracks, for: favorites.id)

        return publishResult(.added, for: track.trackId)
    }

    /// Удаляет все строки с переданным trackId, сохраняя относительный порядок остальных треков.
    @discardableResult
    func remove(trackId: UUID) throws -> FavoritesMutationResult {
        let favorites = try resolvedFavoritesTrackList()
        let tracks = try trackListManager.loadTracks(for: favorites.id)
        let updatedTracks = tracks.filter { $0.trackId != trackId }

        guard updatedTracks.count != tracks.count else {
            return .unchanged(isFavorite: false)
        }

        try save(updatedTracks, for: favorites.id)

        return publishResult(.removed, for: trackId)
    }

    /// Выполняет одну последовательную проверку и изменение, не разделяя toggle на внешние вызовы isFavorite и add/remove.
    @discardableResult
    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        let favorites = try resolvedFavoritesTrackList()
        let tracks = try trackListManager.loadTracks(for: favorites.id)

        if tracks.contains(where: { $0.trackId == track.trackId }) {
            let updatedTracks = tracks.filter { $0.trackId != track.trackId }
            try save(updatedTracks, for: favorites.id)
            return publishResult(.removed, for: track.trackId)
        }

        var updatedTracks = tracks
        updatedTracks.append(track.makeTrackListTrack())
        try save(updatedTracks, for: favorites.id)
        return publishResult(.added, for: track.trackId)
    }

    /// Находит системный треклист по kind или делегирует его создание и восстановление существующему manager-слою.
    private func resolvedFavoritesTrackList() throws -> TrackListMeta {
        if let favorites = try trackListsManager.favoritesTrackList() {
            return favorites
        }

        return try trackListsManager.ensureFavoritesTrackList()
    }

    /// Сохраняет изменённое содержимое через существующий manager-путь, оставляя публикацию точечного события сервису и преобразуя ошибку в AppError.
    private func save(
        _ tracks: [Track],
        for trackListId: UUID
    ) throws {
        guard trackListManager.saveTracks(
            tracks,
            for: trackListId,
            publishesFavoritesEvents: false
        ) else {
            throw AppError.trackListSaveFailed
        }
    }

    /// Публикует ровно одно событие после успешного сохранения и только при фактическом изменении состояния.
    private func publishResult(
        _ result: FavoritesMutationResult,
        for trackId: UUID
    ) -> FavoritesMutationResult {
        guard result.didChange else {
            return result
        }

        favoritesEvents.publish(
            FavoritesChangeEvent(
                trackId: trackId,
                isFavorite: result.isFavorite
            )
        )

        return result
    }
}

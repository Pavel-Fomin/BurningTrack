//
//  TrackListManager.swift
//  TrackList
//
//  Менеджер для работы с одним треклистом:
//  - Загрузка и сохранение треков (Track)
//  - Получение треклиста по ID
//  - Валидация имени
//
//  Created by Pavel Fomin on 27.04.2025.
//

import Foundation

enum TrackListStorageError: Error, Sendable {
    case saveFailed(trackListId: UUID)
}

/// Подтверждает, что новое содержимое треклиста сохранено в SQLite и опубликовано подписчикам.
struct TrackListTracksSaveReceipt: Sendable, Equatable {
    let trackListId: UUID
    let savedTracksCount: Int
}

@MainActor
final class TrackListManager {
    
    static let shared = TrackListManager()
    private let databaseStore: TrackListDatabaseStore
    /// Передаёт точечные изменения состава системного треклиста без зависимости от ViewModel.
    private let favoritesEvents: any FavoritesEventsPublishing

    private init() {
        do {
            self.databaseStore = try TrackListDatabaseStore()
            self.favoritesEvents = FavoritesEventCenter.shared
        } catch {
            preconditionFailure("Не удалось создать TrackListDatabaseStore: \(error)")
        }
    }

    /// Инициализатор для изолированных сценариев и тестов с переданным SQLite-фасадом.
    init(databaseStore: TrackListDatabaseStore) {
        self.databaseStore = databaseStore
        self.favoritesEvents = FavoritesEventCenter.shared
    }

    /// Инициализатор для изолированных сценариев и тестов с явным каналом событий Favorites.
    init(
        databaseStore: TrackListDatabaseStore,
        favoritesEvents: any FavoritesEventsPublishing
    ) {
        self.databaseStore = databaseStore
        self.favoritesEvents = favoritesEvents
    }
    
    
    // MARK: - Работа с треками SQLite
    
    /// Загружает треки по ID треклиста из SQLite.
    func loadTracks(for id: UUID) throws -> [Track] {
        do {
            return try databaseStore.fetchTracks(for: id)
        } catch TrackListDatabaseStoreError.trackListNotFound {
            throw AppError.trackListNotFound
        } catch {
            PersistentLogger.log("❌ TrackListManager: SQLite loadTracks failed id=\(id) error=\(error)")
            throw AppError.trackListLoadFailed
        }
    }
    
    /// Сохраняет треки по ID треклиста в SQLite и возвращает receipt только после публикации изменений.
    func saveTracks(
        _ tracks: [Track],
        for id: UUID,
        postTrackListsDidChange: Bool = true,
        publishesFavoritesEvents: Bool = true
    ) throws -> TrackListTracksSaveReceipt {
        do {
            let isFavoritesTrackList: Bool
            if publishesFavoritesEvents {
                isFavoritesTrackList = try databaseStore.fetchMeta(id: id).kind == .favorites
            } else {
                isFavoritesTrackList = false
            }
            let favoritesTracksBeforeSaving: [Track]
            if isFavoritesTrackList {
                favoritesTracksBeforeSaving = try databaseStore.fetchTracks(for: id)
            } else {
                favoritesTracksBeforeSaving = []
            }

            try databaseStore.replaceTracks(tracks, for: id)
            if isFavoritesTrackList {
                publishFavoritesChanges(
                    from: favoritesTracksBeforeSaving,
                    to: tracks
                )
            }
            NotificationCenter.default.post(
                name: .trackListTracksDidChange,
                object: id
            )
            if postTrackListsDidChange, TrackListsManager.shared.trackListExists(id: id) {
                NotificationCenter.default.post(
                    name: .trackListsDidChange,
                    object: nil
                )
            }
            PersistentLogger.log("💾 TrackListManager: saved SQLite tracks=\(tracks.count) id=\(id)")
            return TrackListTracksSaveReceipt(
                trackListId: id,
                savedTracksCount: tracks.count
            )
        } catch {
            PersistentLogger.log("❌ TrackListManager: SQLite saveTracks failed id=\(id) tracks=\(tracks.count) error=\(error)")
            throw AppError.trackListSaveFailed
        }
    }

    /// Публикует изменения множества trackId системного треклиста, не реагируя на порядок и обновление snapshot.
    private func publishFavoritesChanges(
        from previousTracks: [Track],
        to updatedTracks: [Track]
    ) {
        guard previousTracks.isEmpty == false || updatedTracks.isEmpty == false else {
            return
        }

        let previousTrackIds = Set(previousTracks.map(\.trackId))
        let updatedTrackIds = Set(updatedTracks.map(\.trackId))
        var publishedTrackIds = Set<UUID>()

        for track in previousTracks
        where updatedTrackIds.contains(track.trackId) == false && publishedTrackIds.insert(track.trackId).inserted {
            favoritesEvents.publish(
                FavoritesChangeEvent(
                    trackId: track.trackId,
                    isFavorite: false
                )
            )
        }

        for track in updatedTracks
        where previousTrackIds.contains(track.trackId) == false && publishedTrackIds.insert(track.trackId).inserted {
            favoritesEvents.publish(
                FavoritesChangeEvent(
                    trackId: track.trackId,
                    isFavorite: true
                )
            )
        }
    }
    
    // MARK: - Возвращает объект треклиста
    
    /// Возвращает треклист с треками и метаданными по его ID из SQLite.
    func getTrackListById(_ id: UUID) throws -> TrackList {
        do {
            return try databaseStore.fetchTrackList(id: id)
        } catch TrackListDatabaseStoreError.trackListNotFound {
            throw AppError.trackListNotFound
        } catch {
            PersistentLogger.log("❌ TrackListManager: SQLite getTrackListById failed id=\(id) error=\(error)")
            throw AppError.trackListLoadFailed
        }
    }

    // MARK: - Добавление треков

    /// Добавляет готовые модели Track в существующий треклист и сохраняет его в SQLite.
    /// Повторные вхождения одного trackId разрешены, потому что это отдельные элементы треклиста.
    @discardableResult
    func addTracks(
        _ tracksToAdd: [Track],
        to trackListId: UUID
    ) throws -> TrackList {
        var list = try getTrackListById(trackListId)

        guard !tracksToAdd.isEmpty else {
            return list
        }

        list.tracks.append(contentsOf: tracksToAdd)

        _ = try saveTracks(list.tracks, for: list.id)

        return list
    }
    
    
    // MARK: - Валидация имени
    
    /// Проверяет, что имя не пустое и не состоит только из пробелов
    func validateName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - TrackListManaging

extension TrackListManager: TrackListManaging {

    /// Сохраняет треки и возвращает receipt после уведомления списка треклистов.
    func saveTracks(_ tracks: [Track], for id: UUID) throws -> TrackListTracksSaveReceipt {
        try saveTracks(
            tracks,
            for: id,
            postTrackListsDidChange: true,
            publishesFavoritesEvents: true
        )
    }

    /// Сохраняет треки с возможностью передать публикацию точечного события вызывающему сервису.
    func saveTracks(
        _ tracks: [Track],
        for id: UUID,
        publishesFavoritesEvents: Bool
    ) throws -> TrackListTracksSaveReceipt {
        try saveTracks(
            tracks,
            for: id,
            postTrackListsDidChange: true,
            publishesFavoritesEvents: publishesFavoritesEvents
        )
    }
}

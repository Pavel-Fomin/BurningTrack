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

enum TrackListStorageError: Error {
    case saveFailed(trackListId: UUID)
}

final class TrackListManager {
    
    static let shared = TrackListManager()
    private let databaseStore: TrackListDatabaseStore

    private init() {
        do {
            self.databaseStore = try TrackListDatabaseStore()
        } catch {
            preconditionFailure("Не удалось создать TrackListDatabaseStore: \(error)")
        }
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
    
    /// Сохраняет треки по ID треклиста в SQLite.
    @discardableResult
    func saveTracks(
        _ tracks: [Track],
        for id: UUID,
        postTrackListsDidChange: Bool = true
    ) -> Bool {
        do {
            try databaseStore.replaceTracks(tracks, for: id)
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
            return true
        } catch {
            PersistentLogger.log("❌ TrackListManager: SQLite saveTracks failed id=\(id) tracks=\(tracks.count) error=\(error)")
            return false
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

        guard saveTracks(list.tracks, for: list.id) else {
            throw TrackListStorageError.saveFailed(trackListId: list.id)
        }

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

    /// Сохраняет треки и уведомляет об изменении списка треклистов.
    nonisolated func saveTracks(_ tracks: [Track], for id: UUID) -> Bool {
        saveTracks(
            tracks,
            for: id,
            postTrackListsDidChange: true
        )
    }
}

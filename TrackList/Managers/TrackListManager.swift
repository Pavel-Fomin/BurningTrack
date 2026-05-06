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

enum TrackListStorageError: Error, LocalizedError {
    case saveFailed(trackListId: UUID)

    var errorDescription: String? {
        switch self {
        case .saveFailed(let trackListId):
            return "Не удалось сохранить треклист \(trackListId)"
        }
    }
}

final class TrackListManager {
    
    static let shared = TrackListManager()
    private init() {}
    
    
    // MARK: - Пути
    
    /// Путь к директории /Documents
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory,
                                 in: .userDomainMask).first
    }
    
    /// Путь к JSON-файлу с треками конкретного треклиста
    private func urlForTrackList(id: UUID) -> URL? {
        guard let directory = documentsDirectory else { return nil }
        let fileName = "tracklist_\(id.uuidString).json"
        return directory.appendingPathComponent(fileName)
    }
    
    
    // MARK: - Работа с треками (tracklist_<id>.json)
    
    /// Загружает треки по ID треклиста
    func loadTracks(for id: UUID) throws -> [Track] {
        guard let url = urlForTrackList(id: id) else {
            throw AppError.trackListLoadFailed
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Track].self, from: data)
        } catch {
            throw AppError.trackListLoadFailed
        }
    }
    
    /// Сохраняет треки по ID треклиста
    @discardableResult
    func saveTracks(
        _ tracks: [Track],
        for id: UUID,
        postTrackListsDidChange: Bool = true
    ) -> Bool {
        guard let url = urlForTrackList(id: id) else {
            PersistentLogger.log("❌ TrackListManager: saveTracks url nil id=\(id)")
            return false
        }

        let encoder = makePrettyJSONEncoder()

        guard let data = try? encoder.encode(tracks) else {
            PersistentLogger.log("❌ TrackListManager: encode failed id=\(id) tracks=\(tracks.count)")
            return false
        }

        do {
            try data.write(to: url, options: .atomic)
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
            PersistentLogger.log("💾 TrackListManager: saved tracks=\(tracks.count) id=\(id)")
            return true
        } catch {
            PersistentLogger.log("❌ TrackListManager: write failed id=\(id) error=\(error)")
            return false
        }
    }
    
    /// Удаляет файл с треками треклиста (используется при удалении треклиста)
    func deleteTracksFile(for id: UUID) throws {
        guard let url = urlForTrackList(id: id) else {
            PersistentLogger.log("❌ TrackListManager: deleteTracksFile url nil id=\(id)")
            throw AppError.trackListSaveFailed
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: url)
            PersistentLogger.log("🗑 TrackListManager: deleted tracklist file id=\(id)")
        } catch {
            PersistentLogger.log("❌ TrackListManager: delete failed id=\(id) error=\(error)")
            throw AppError.trackListSaveFailed
        }
    }
    
    
    // MARK: - Возвращает объект треклиста
    
    /// Возвращает треклист с треками и метаданными по его ID
    func getTrackListById(_ id: UUID) throws -> TrackList {
        // Получаем метаданные через TrackListsManager
        let metas = try TrackListsManager.shared.loadTrackListMetas()
        guard let meta = metas.first(where: { $0.id == id }) else {
            throw AppError.trackListNotFound
        }
        
        let tracks = try loadTracks(for: id)
        return TrackList(
            id: id,
            name: meta.name,
            createdAt: meta.createdAt,
            tracks: tracks
        )
    }
    
    
    // MARK: - Валидация имени
    
    /// Проверяет, что имя не пустое и не состоит только из пробелов
    func validateName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

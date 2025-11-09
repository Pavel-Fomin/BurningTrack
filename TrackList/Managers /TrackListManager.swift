//
//  TrackListManager.swift
//  TrackList
//
//  Менеджер для работы с треклистом:
//  - Загрузка и сохранение треков
//  - Получение треклиста по ID
//  - Проверка корректности имени
//
//  Created by Pavel Fomin on 27.04.2025.
//

import Foundation

final class TrackListManager {
    
    static let shared = TrackListManager()
    private init() {}
    
    
    // MARK: - Пути
    
    /// Путь к директории /Documents
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    /// Возвращает путь к JSON-файлу с треками конкретного треклиста
    private func urlForTrackList(id: UUID) -> URL? {
        guard let directory = documentsDirectory else { return nil }
        let fileName = "tracklist_\(id.uuidString).json"
        return directory.appendingPathComponent(fileName)
    }
    
    
    // MARK: - Работа с треками (tracklist_<id>.json)
    
    /// Загружает треки по ID треклиста
    func loadTracks(for id: UUID) -> [ImportedTrack] {
        guard
            let url = urlForTrackList(id: id),
            let data = try? Data(contentsOf: url),
            let tracks = try? JSONDecoder().decode([ImportedTrack].self, from: data)
        else {
            return []
        }
        return tracks
    }
    
    /// Сохраняет треки по ID треклиста
    func saveTracks(_ tracks: [ImportedTrack], for id: UUID) {
        guard let url = urlForTrackList(id: id) else { return }
        
        let encoder = makePrettyJSONEncoder()
        if let data = try? encoder.encode(tracks) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    
    // MARK: - Возвращает объект треклиста
    
    /// Возвращает треклист с треками и метаданными по его ID
    func getTrackListById(_ id: UUID) -> TrackList {
        // Получаем метаданные через TrackListsManager
        let metas = TrackListsManager.shared.loadTrackListMetas()
        guard let meta = metas.first(where: { $0.id == id }) else {
            fatalError("❌ Треклист с id \(id) не найден")
        }
        
        let tracks = loadTracks(for: id)
        return TrackList(id: id, name: meta.name, createdAt: meta.createdAt, tracks: tracks)
    }
    
    
    // MARK: - Валидация имени
    
    /// Проверяет, что имя не пустое и не состоит только из пробелов
    func validateName(_ name: String) -> Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

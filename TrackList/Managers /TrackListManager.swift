//
//  TrackListManager.swift
//  TrackList
//
//  Менеджер для работы с треклистами (чтение и сохранение JSON)
//
//  Created by Pavel Fomin on 27.04.2025.
//

import Foundation

final class TrackListManager {
    static let shared = TrackListManager()  // Singleton для удобства
    private init() {}
    
    
    // MARK: - Директория с плейлистами
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    // MARK: - Загрузка списка всех плейлистов (метаинформация)
    func loadTrackListMetas() -> [TrackListMeta] {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tracklists.json"),
              let data = try? Data(contentsOf: url),
              let metas = try? JSONDecoder().decode([TrackListMeta].self, from: data) else {
            return []
        }
        return metas
    }
    
    
    // MARK: - Загрузка треков по ID плейлиста
    func loadTracks(for id: UUID) -> [ImportedTrack] {
        guard let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tracklist_\(id.uuidString).json"),
              let data = try? Data(contentsOf: url),
              let tracks = try? JSONDecoder().decode([ImportedTrack].self, from: data) else {
            return []
        }
        return tracks
    }
    
    // MARK: - Сохранение треков по ID плейлиста
    func saveTracks(_ tracks: [ImportedTrack], for id: UUID) {
        guard let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tracklist_\(id.uuidString).json") else {
            return
        }
        
        if let data = try? JSONEncoder().encode(tracks) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    // MARK: - Сохранение списка всех плейлистов (метаинформация)
    func saveTrackListMetas(_ metas: [TrackListMeta]) {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tracklists.json") else { return }
        
        if let data = try? JSONEncoder().encode(metas) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    // MARK: - Проверка существования треклиста по ID
    func trackListExists(id: UUID) -> Bool {
        return loadTrackListMetas().contains(where: { $0.id == id })
    }
    
    // MARK: - ID выбранного треклиста (опционально)
    private(set) var selectedTrackListId: UUID?
    
    // MARK: - Выбрать активный треклист по id
    func selectTrackList(id: UUID) {
        let metas = loadTrackListMetas()
        if metas.contains(where: { $0.id == id }) {
            selectedTrackListId = id
            print("✅ Выбран плейлист с id: \(id)")
        } else {
            print("❌ Плейлист с таким id не найден")
        }
    }
    
    // MARK: - Вывести содержимое всех треклистов в консоль (для отладки)
    func printTrackLists() {
        let metas = loadTrackListMetas()
        print("\n===== СОДЕРЖИМОЕ ВСЕХ ТРЕКЛИСТОВ =====")
        for meta in metas {
            let tracks = loadTracks(for: meta.id)
            print("Плейлист: \(meta.name), ID: \(meta.id)")
            for track in tracks {
                print("— \(track.fileName) (\(track.artist ?? "неизвестный артист") — \(track.title ?? "неизвестный трек")), duration: \(track.duration)")
            }
        }
        
    }
    // MARK: - Получить выбранный треклист (если выбран)
    func getCurrentTrackList() -> TrackList? {
        guard let id = selectedTrackListId else {
            print("⚠️ Текущий плейлист не выбран")
            return nil
        }
        
        let metas = loadTrackListMetas()
        guard let meta = metas.first(where: { $0.id == id }) else {
            print("❌ Метаинформация не найдена для ID: \(id)")
            return nil
        }
        
        let tracks = loadTracks(for: id)
        return TrackList(id: id, name: meta.name, createdAt: meta.createdAt, tracks: tracks)
    }
    
    // MARK: - Сохранение всех плейлистов (метаинформация + треки)
    func saveTrackLists(_ trackLists: [TrackList]) {
        // 1. Сохраняем треки по ID
        for list in trackLists {
            saveTracks(list.tracks, for: list.id)
        }
        
        // 2. Сохраняем метаинформацию
        let metas = trackLists.map { TrackListMeta(id: $0.id, name: $0.name, createdAt: $0.createdAt) }
        saveTrackListMetas(metas)
        
        print("✅ Все плейлисты сохранены (отдельно треки и мета)")
    }
    
    // MARK: - Получить или создать "дефолтный" треклист
    func getOrCreateDefaultTrackList() -> TrackList {
        let metas = loadTrackListMetas()
        if let firstMeta = metas.first {
            let tracks = loadTracks(for: firstMeta.id)
            let list = TrackList(id: firstMeta.id, name: firstMeta.name, createdAt: firstMeta.createdAt, tracks: tracks)
            selectedTrackListId = list.id
            return list
        }
        // Если нет ни одного — создаём новый
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        let name = formatter.string(from: Date())
        
        let new = TrackList(
            id: UUID(),
            name: name,
            createdAt: Date(),
            tracks: []
        )
        
        saveTrackLists([new])
        selectedTrackListId = new.id
        print("🆕 Создан новый плейлист: \(name)")
        return new
    }
    
    // MARK: - Создать пустой треклист и вернуть его
    func createEmptyTrackList() -> TrackList {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        let name = formatter.string(from: Date())
        
        let newId = UUID()
        let createdAt = Date()
        
        // 1. Сохраняем пустой треклист
        saveTracks([], for: newId)
        
        // 2. Обновляем список метаинформации
        var metas = loadTrackListMetas()
        let newMeta = TrackListMeta(id: newId, name: name, createdAt: createdAt)
        metas.append(newMeta)
        saveTrackListMetas(metas)
        
        // 3. Обновляем текущий
        selectedTrackListId = newId
        print("🆕 Новый пустой плейлист создан: \(name)")
        
        return TrackList(id: newId, name: name, createdAt: createdAt, tracks: [])
    }
    
    
    // MARK: - Создать новый треклист из массива ImportedTrack
    @discardableResult
    func createTrackList(from importedTracks: [ImportedTrack]) -> TrackList {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        let name = formatter.string(from: Date())
        
        let newId = UUID()
        let createdAt = Date()
        
        // Сохраняем треки
        saveTracks(importedTracks, for: newId)
        
        // Обновляем метаинформацию
        var metas = loadTrackListMetas()
        let newMeta = TrackListMeta(id: newId, name: name, createdAt: createdAt)
        metas.append(newMeta)
        saveTrackListMetas(metas)
        
        selectedTrackListId = newId
        return TrackList(id: newId, name: name, createdAt: createdAt, tracks: importedTracks)
    }
    
    
    // MARK: - Удаляет треклист по ID: удаляет JSON-файл и убирает мету из tracklists.json
    func deleteTrackList(id: UUID) {
        // 1. Удаляем файл с треками
        if let fileURL = documentsDirectory?.appendingPathComponent("tracklist_\(id.uuidString).json") {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ Удалён файл: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ Не удалось удалить файл: \(error)")
            }
        }

        // 2. Загружаем и фильтруем метаинформацию
        var metas = loadTrackListMetas()
        metas.removeAll { $0.id == id }

        // 3. Сохраняем обновлённую мету
        saveTrackListMetas(metas)
        
        print("🗑️ Треклист с ID \(id) удалён")
    }
}

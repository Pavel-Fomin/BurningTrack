//
//  TrackListsManager.swift
//  TrackList
//
//  Менеджер для списка всех треклистов
//  Отвечает за работу с файлом tracklists.json (метаинформация о всех треклистах)
//  Cоздание/удаление/переименование отдельных треклистов
//
//  Created by Pavel Fomin on 07.11.2025.
//

import Foundation

final class TrackListsManager {
    
    static let shared = TrackListsManager()
    private init() {}
    
    
    // MARK: - Модель метаинформации
    
    struct TrackListMeta: Identifiable, Codable, Equatable {
        let id: UUID
        var name: String
        let createdAt: Date
    }
    
    // MARK: - Метаданные (tracklists.json)
    
    /// Загружает список всех треклистов (метаданных) из tracklists.json
    func loadTrackListMetas() -> [TrackListMeta] {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tracklists.json"),
              let data = try? Data(contentsOf: url),
              let metas = try? JSONDecoder().decode([TrackListMeta].self, from: data) else {
            return []
        }
        return metas
    }
    
    /// Сохраняет список всех треклистов (метаинформацию) в tracklists.json
    func saveTrackListMetas(_ metas: [TrackListMeta]) {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tracklists.json") else { return }
        
        let encoder = makePrettyJSONEncoder()
        if let data = try? encoder.encode(metas) {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    /// Проверяет, существует ли треклист с указанным ID
    func trackListExists(id: UUID) -> Bool {
        return loadTrackListMetas().contains(where: { $0.id == id })
    }
    
    
    // MARK: - Создание треклистов
    
    /// Создаёт новый треклист с текущей датой в названии
    @discardableResult
    func createTrackList(from importedTracks: [ImportedTrack]) -> TrackList {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        let name = formatter.string(from: Date())
        
        let newId = UUID()
        let createdAt = Date()
        
        // делегируем сохранение треков в TrackListManager
        TrackListManager.shared.saveTracks(importedTracks, for: newId)
        
        var metas = loadTrackListMetas()
        let newMeta = TrackListMeta(id: newId, name: name, createdAt: createdAt)
        metas.append(newMeta)
        saveTrackListMetas(metas)
        
        return TrackList(id: newId, name: name, createdAt: createdAt, tracks: importedTracks)
    }
    
    /// Создаёт треклист с заданным именем (используется для ручного ввода)
    func createTrackList(from tracks: [ImportedTrack], withName name: String) -> TrackList {
        let id = UUID()
        let createdAt = Date()
        let meta = TrackListMeta(id: id, name: name, createdAt: createdAt)
        
        saveTrackListMeta(meta)
        TrackListManager.shared.saveTracks(tracks, for: id)
        
        return TrackList(id: id, name: name, createdAt: createdAt, tracks: tracks)
    }
    
    /// Сохраняет один TrackListMeta в общий список (tracklists.json)
    func saveTrackListMeta(_ meta: TrackListMeta) {
        var current = loadTrackListMetas()
        current.append(meta)
        saveTrackListMetas(current)
    }
    
    
    // MARK: - Удаление и переименование
    
    /// Удаляет плейлист по ID: треки, мета, обложки
    func deleteTrackList(id: UUID) {
        // Удаляем JSON-файл с треками
        if let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tracklist_\(id.uuidString).json") {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        // Удаляем из списка мета
        var metas = loadTrackListMetas()
        metas.removeAll { $0.id == id }
        saveTrackListMetas(metas)
        print("🗑️ Треклист \(id) удалён")
    }
    
    /// Переименовывает треклист по ID
    func renameTrackList(id: UUID, to newName: String) {
        var metas = loadTrackListMetas()
        guard let index = metas.firstIndex(where: { $0.id == id }) else { return }
        
        metas[index].name = newName
        saveTrackListMetas(metas)
    }
    
    
    // MARK: - Сохранение всех треклистов
    
    /// Сохраняет все треклисты (отдельно JSON с треками и tracklists.json с мета)
    func saveTrackLists(_ trackLists: [TrackList]) {
        for list in trackLists {
            TrackListManager.shared.saveTracks(list.tracks, for: list.id)
        }
        
        let metas = trackLists.map {
            TrackListMeta(id: $0.id, name: $0.name, createdAt: $0.createdAt)
        }
        
        saveTrackListMetas(metas)
        
        print("✅ Все плейлисты сохранены (отдельно треки и мета)")
    }
    
    
    // MARK: - Отладка
    
    /// Выводит все треклисты и их содержимое в консоль
    func printTrackLists() {
        let metas = loadTrackListMetas()
        print("\n===== СОДЕРЖИМОЕ ВСЕХ ТРЕКЛИСТОВ =====")
        for meta in metas {
            let tracks = TrackListManager.shared.loadTracks(for: meta.id)
            print("Плейлист: \(meta.name), ID: \(meta.id)")
            for track in tracks {
                print("— \(track.fileName) (\(track.artist ?? "неизвестный артист") — \(track.title ?? "неизвестный трек")), duration: \(track.duration)")
            }
        }
    }
}

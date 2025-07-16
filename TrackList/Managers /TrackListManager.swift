//
//  TrackListManager.swift
//  TrackList
//
//  Менеджер для работы с треклистами:
//  - Загрузка и сохранение треков и метаинформации
//  - Управление выбранным треклистом
//  - Создание, удаление и переименование плейлистов
//
//  Created by Pavel Fomin on 27.04.2025.
//

import Foundation

final class TrackListManager {
    static let shared = TrackListManager()  /// Singleton для централизованного доступа
    private init() {}

    
// MARK: - Пути
    
    // Ссылка на папку /Documents
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    // Возвращает URL для JSON-файла треклиста
    private func urlForTrackList(id: UUID, isDraft: Bool = false) -> URL? {
        guard let directory = documentsDirectory else { return nil }
        let fileName = isDraft ? "tracklist_draft.json" : "tracklist_\(id.uuidString).json"
        return directory.appendingPathComponent(fileName)
    }

    
// MARK: - Метаданные (tracklists.json)

    // Загружает список всех треклистов из tracklists.json
    func loadTrackListMetas() -> [TrackListMeta] {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tracklists.json"),
              let data = try? Data(contentsOf: url),
              let metas = try? JSONDecoder().decode([TrackListMeta].self, from: data) else {
            return []
        }
        return metas
    }

    // Сохраняет список всех треклистов в tracklists.json
    func saveTrackListMetas(_ metas: [TrackListMeta]) {
        guard let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("tracklists.json") else { return }

        if let data = try? JSONEncoder().encode(metas) {
            try? data.write(to: url, options: .atomic)
        }
    }

    // Проверяет, существует ли плейлист с указанным ID
    func trackListExists(id: UUID) -> Bool {
        return loadTrackListMetas().contains(where: { $0.id == id })
    }

    
// MARK: - Треки (tracklist_<id>.json)

    // Загружает треки из файла по ID плейлиста
    func loadTracks(for id: UUID, isDraft: Bool = false) -> [ImportedTrack] {
        guard let url = urlForTrackList(id: id, isDraft: isDraft),
              let data = try? Data(contentsOf: url),
              let tracks = try? JSONDecoder().decode([ImportedTrack].self, from: data) else {
            return []
        }
        return tracks
    }

    // Сохраняет список треков по ID плейлиста
    func saveTracks(_ tracks: [ImportedTrack], for id: UUID, isDraft: Bool = false) {
        guard let url = urlForTrackList(id: id, isDraft: isDraft) else { return }

        if let data = try? JSONEncoder().encode(tracks) {
            try? data.write(to: url, options: .atomic)
        }
    }

    
// MARK: - Возвращает треклист по его ID
    
    // - Parameter id: Уникальный идентификатор треклиста
    // - Returns: Полноценный объект TrackList с метаинформацией и треками
    // - Note: Если плейлист не найден — приложение завершится с ошибкой (fatalError)
    func getTrackListById(_ id: UUID) -> TrackList {
        let metas = loadTrackListMetas()
        guard let meta = metas.first(where: { $0.id == id }) else {
            fatalError("Плейлист не найден")
        }
        let tracks = loadTracks(for: id, isDraft: meta.isDraft)
        return TrackList(id: id, name: meta.name, createdAt: meta.createdAt, tracks: tracks)
    }
    

// MARK: - Создание треклистов


    // Создаёт новый плейлист из импортированных треков
    @discardableResult
    func createTrackList(from importedTracks: [ImportedTrack]) -> TrackList {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        let name = formatter.string(from: Date())

        let newId = UUID()
        let createdAt = Date()

        saveTracks(importedTracks, for: newId)

        var metas = loadTrackListMetas()
        let newMeta = TrackListMeta(id: newId, name: name, createdAt: createdAt, isDraft: false)
        metas.append(newMeta)
        
        saveTrackListMetas(metas)

        return TrackList(id: newId, name: name, createdAt: createdAt, tracks: importedTracks)
    }

    
// MARK: - Удаление и переименование

    // Удаляет треклист: удаляет JSON с треками, метаинформацию и обложки
    func deleteTrackList(id: UUID) {
        
        // Удаляем обложки
        let tracks = loadTracks(for: id)
        for track in tracks {
            if let artworkId = track.artworkId {
                ArtworkManager.deleteArtwork(id: artworkId)
            }
        }

        // Удаляем JSON-файл с треками
        if let fileURL = documentsDirectory?.appendingPathComponent("tracklist_\(id.uuidString).json") {
            do {
                try FileManager.default.removeItem(at: fileURL)
                print("✅ Удалён файл: \(fileURL.lastPathComponent)")
            } catch {
                print("❌ Не удалось удалить файл: \(error)")
            }
        }

        // Обновляем tracklists.json
        var metas = loadTrackListMetas()
        metas.removeAll { $0.id == id }
        saveTrackListMetas(metas)

        print("🗑️ Треклист с ID \(id) удалён")
    }

    // Создает треклист
    func createTrackList(from tracks: [ImportedTrack], withName name: String) -> TrackList {
        let id = UUID()
        let createdAt = Date()
        let meta = TrackListMeta(id: id, name: name, createdAt: createdAt)

        saveTrackListMeta(meta)
        saveTracks(tracks, for: id)

        return TrackList(id: id, name: name, createdAt: createdAt, tracks: tracks)
    }
    
    // Сохраняет метаинформацию о треклисте в tracklists.json
    func saveTrackListMeta(_ meta: TrackListMeta) {
        var current = loadTrackListMetas()
        current.append(meta)
        saveTrackListMetas(current)
    }
    
    
// MARK: - Сохранение всех треклистов

    // Сохраняет все треклисты (треки + мета)
    func saveTrackLists(_ trackLists: [TrackList]) {
        for list in trackLists {
            saveTracks(list.tracks, for: list.id)
        }

        let metas = trackLists.map {
            TrackListMeta(id: $0.id, name: $0.name, createdAt: $0.createdAt, isDraft: false)
        }

        saveTrackListMetas(metas)

        print("✅ Все плейлисты сохранены (отдельно треки и мета)")
    }
    
    
    // MARK: - Переименование
    func renameTrackList(id: UUID, to newName: String) {
        var metas = loadTrackListMetas()
        guard let index = metas.firstIndex(where: { $0.id == id }) else { return }

        metas[index].name = newName
        saveTrackListMetas(metas)
    }

    
// MARK: - Отладка

    // Печатает содержимое всех треклистов в консоль
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
    
}


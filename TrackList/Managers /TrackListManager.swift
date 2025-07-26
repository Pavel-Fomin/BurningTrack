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
    
    /// Синглтон-экземпляр
    static let shared = TrackListManager()
    private init() {}

    
// MARK: - Пути
    
    /// Путь к директории /Documents
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    /// Возвращает путь к JSON-файлу с треками плейлиста
    /// - Parameters:
    /// - id: UUID треклиста
    /// - isDraft: true — если это черновик (draft)
    private func urlForTrackList(id: UUID) -> URL? {
        guard let directory = documentsDirectory else { return nil }
        let fileName = "tracklist_\(id.uuidString).json"
        return directory.appendingPathComponent(fileName)
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

    
// MARK: - Треки (tracklist_<id>.json)

    /// Загружает треки по ID треклиста
    /// - Parameters:
    /// - id: ID плейлиста
    /// - isDraft: Если true — используется файл черновика
    /// - Returns: Массив импортированных треков
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

    /// Сохраняет треки по ID треклиста (включая draft)
    func saveTracks(_ tracks: [ImportedTrack], for id: UUID) {
        guard let url = urlForTrackList(id: id) else { return }

        let encoder = makePrettyJSONEncoder()
        if let data = try? encoder.encode(tracks) {
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
        let tracks = loadTracks(for: id)
        return TrackList(id: id, name: meta.name, createdAt: meta.createdAt, tracks: tracks)
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

        saveTracks(importedTracks, for: newId)

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
        saveTracks(tracks, for: id)

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

        // Удаляем из списка мета
        var metas = loadTrackListMetas()
        metas.removeAll { $0.id == id }
        saveTrackListMetas(metas)
        print("🗑️ Треклист с ID \(id) удалён")
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
            saveTracks(list.tracks, for: list.id)
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
            let tracks = loadTracks(for: meta.id)
            print("Плейлист: \(meta.name), ID: \(meta.id)")
            for track in tracks {
                print("— \(track.fileName) (\(track.artist ?? "неизвестный артист") — \(track.title ?? "неизвестный трек")), duration: \(track.duration)")
            }
        }
    }
    
}


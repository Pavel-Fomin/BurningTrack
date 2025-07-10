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

    
// MARK: - Инициализация дефолтного треклиста
    
       // Проверяет наличие хотя бы одного треклиста и активного ID. Если нет — создаёт дефолтный треклист "Черновик"
       func initializeDefaultTrackListIfNeeded() {
           var metas = loadTrackListMetas()

           // 1. Создаём дефолтный треклист, если ни одного не существует
           if metas.isEmpty {
               let id = UUID()
               let meta = TrackListMeta(id: id, name: "Черновик", createdAt: Date(), isDraft: true)
               metas.append(meta)
               saveTrackListMetas(metas)
               saveTracks([], for: id, isDraft: true)
               selectedTrackListId = id
               print("📄 Создан дефолтный плейлист")
               return
           }

           // 2. Если активный ID не выбран — выбираем первый доступный
           if selectedTrackListId == nil {
               selectedTrackListId = metas.first?.id
               print("📌 Установлен выбранный плейлист: \(selectedTrackListId?.uuidString ?? "nil")")
           }
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
    
// MARK: - Управление текущим плейлистом

    // ID выбранного плейлиста
    private(set) var selectedTrackListId: UUID?

    // Устанавливает активный плейлист
    func selectTrackList(id: UUID) {
        let metas = loadTrackListMetas()
        if metas.contains(where: { $0.id == id }) {
            selectedTrackListId = id
            print("✅ Выбран плейлист с id: \(id)")
        } else {
            print("❌ Плейлист с таким id не найден")
        }
    }

    // Получает текущий выбранный треклист (или nil, если не выбран)
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

        let tracks = loadTracks(for: id, isDraft: meta.isDraft)
        return TrackList(id: id, name: meta.name, createdAt: meta.createdAt, tracks: tracks)
    }

    
// MARK: - Создание треклистов

    // Возвращает первый треклист или создаёт новый, если ничего нет
    func getOrCreateDefaultTrackList() -> TrackList {
        let metas = loadTrackListMetas()
        if let firstMeta = metas.first {
            let tracks = loadTracks(for: firstMeta.id)
            let list = TrackList(id: firstMeta.id, name: firstMeta.name, createdAt: firstMeta.createdAt, tracks: tracks)
            selectedTrackListId = list.id
            return list
        }

        // Если ни одного плейлиста нет — создаём новый
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

    // Создаёт пустой треклист и сохраняет его
    func createEmptyTrackList() -> TrackList {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        let name = formatter.string(from: Date())

        let newId = UUID()
        let createdAt = Date()

        saveTracks([], for: newId)

        var metas = loadTrackListMetas()
        let newMeta = TrackListMeta(id: newId, name: name, createdAt: createdAt, isDraft: false)
        metas.append(newMeta)
        saveTrackListMetas(metas)

        selectedTrackListId = newId
        print("🆕 Новый пустой плейлист создан: \(name)")

        return TrackList(id: newId, name: name, createdAt: createdAt, tracks: [])
    }

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

        selectedTrackListId = newId

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

    // Переименовывает плейлист по его ID
    func renameTrackList(id: UUID, to newName: String) {
        var meta = loadTrackListMetas()

        guard let index = meta.firstIndex(where: { $0.id == id }) else {
            print("❌ Не найден треклист с id: \(id)")
            return
        }

        meta[index].name = newName
        saveTrackListMetas(meta)
        print("✏️ Название треклиста обновлено: \(newName)")
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

        print("✅ Все плейлисты сохранены (отдельно треки и мета)")
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
    
    func appendTrackToCurrentList(_ track: ImportedTrack) {
        guard let id = selectedTrackListId else {
            print("⚠️ Нет активного треклиста — не могу добавить")
            return
        }

        let metas = loadTrackListMetas()
        let isDraft = metas.first(where: { $0.id == id })?.isDraft ?? false

        var tracks = loadTracks(for: id, isDraft: isDraft)


        guard !tracks.contains(where: { $0.id == track.id }) else {
            print("⚠️ Трек уже в списке")
            return
        }

        tracks.append(track)
        saveTracks(tracks, for: id, isDraft: isDraft)
        print("➕ Трек добавлен в плейлист: \(track.fileName)")
    }
}

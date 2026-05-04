//
//  TrackListsManager.swift
//  TrackList
//
//  Менеджер для списка всех треклистов.
//  Отвечает за работу с файлом tracklists.json (метаинформация о всех треклистах):
//  - создание / удаление / переименование треклистов
//  - сохранение и загрузка списка TrackListMeta
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
    
    
    // MARK: - Пути
    
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory,
                                 in: .userDomainMask).first
    }
    
    private var metasURL: URL? {
        documentsDirectory?.appendingPathComponent("tracklists.json")
    }
    
    
    // MARK: - Метаданные (tracklists.json)
    
    /// Загружает список всех треклистов (метаданных) из tracklists.json
    func loadTrackListMetas() -> [TrackListMeta] {
        guard
            let url = metasURL,
            let data = try? Data(contentsOf: url),
            let metas = try? JSONDecoder().decode([TrackListMeta].self, from: data)
        else {
            return []
        }
        return metas
    }
    
    /// Сохраняет список всех треклистов (метаинформацию) в tracklists.json
    func saveTrackListMetas(_ metas: [TrackListMeta]) {
        _ = persistTrackListMetas(metas)
    }

    private func postTrackListsDidChange() {
        NotificationCenter.default.post(
            name: .trackListsDidChange,
            object: nil
        )
    }

    @discardableResult
    private func persistTrackListMetas(
        _ metas: [TrackListMeta],
        postDidChange: Bool = true
    ) -> Bool {
        guard let url = metasURL else {
            PersistentLogger.log("❌ TrackListsManager: metas url nil")
            return false
        }
        
        let encoder = makePrettyJSONEncoder()
        guard let data = try? encoder.encode(metas) else {
            PersistentLogger.log("❌ TrackListsManager: encode metas failed count=\(metas.count)")
            return false
        }

        do {
            try data.write(to: url, options: .atomic)
            if postDidChange {
                postTrackListsDidChange()
            }
            return true
        } catch {
            PersistentLogger.log("❌ TrackListsManager: write metas failed error=\(error)")
            return false
        }
    }
    
    /// Проверяет, существует ли треклист с указанным ID
    func trackListExists(id: UUID) -> Bool {
        loadTrackListMetas().contains { $0.id == id }
    }
    
    
    // MARK: - Создание треклистов

    // Базовый метод создания треклиста.
    /// Используется всеми сценариями создания (из фонотеки, из шита и т.д.).
    @discardableResult
    private func createTrackListInternal(tracks: [Track], name: String) throws -> TrackList {
        let id = UUID()
        let createdAt = Date()
        
        // Сохраняем треки
        guard TrackListManager.shared.saveTracks(
            tracks,
            for: id,
            postTrackListsDidChange: false
        ) else {
            throw TrackListStorageError.saveFailed(trackListId: id)
        }
        
        // Сохраняем мета
        let meta = TrackListMeta(id: id, name: name, createdAt: createdAt)
        saveTrackListMeta(meta)

        return TrackList(id: id, name: name, createdAt: createdAt, tracks: tracks)
    }

    // Создаёт новый треклист с авто-именем по дате ("dd.MM.yy, HH:mm")
    @discardableResult
    func createTrackList(from tracks: [Track]) throws -> TrackList {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        let name = formatter.string(from: Date())
        
        return try createTrackListInternal(tracks: tracks, name: name)
    }

    // Создаёт треклист с заданным именем (используется для ручного ввода)
    @discardableResult
    func createTrackList(from tracks: [Track], withName name: String) throws -> TrackList {
        return try createTrackListInternal(tracks: tracks, name: name)
    }

    /// Создаёт пустой треклист с заданным именем.
    @discardableResult
    func createEmptyTrackList(withName name: String) throws -> TrackList {
        try createTrackList(from: [Track](), withName: name)
    }

    // Создаёт новый треклист из треков фонотеки.
    /// Метод конвертирует LibraryTrack в Track и использует общий путь создания треклиста.
    @discardableResult
    func createTrackList(from libraryTracks: [LibraryTrack]) throws -> TrackList {
        let tracks = libraryTracks.map { Track(libraryTrack: $0) }
        return try createTrackList(from: tracks)
    }

    // Создаёт новый треклист из треков фонотеки с заданным именем.
    /// Метод используется там, где пользователь вручную задаёт название треклиста.
    @discardableResult
    func createTrackList(from libraryTracks: [LibraryTrack], withName name: String) throws -> TrackList {
        let tracks = libraryTracks.map { Track(libraryTrack: $0) }
        return try createTrackList(from: tracks, withName: name)
    }

    // Сохраняет один TrackListMeta в общий список (tracklists.json)
    func saveTrackListMeta(_ meta: TrackListMeta) {
        var current = loadTrackListMetas()
        current.append(meta)
        saveTrackListMetas(current)
    }

    // MARK: - Добавление треков

    /// Добавляет треки из фонотеки в существующий треклист.
    /// Уже добавленные треки повторно не добавляются.
    @discardableResult
    func addTracks(_ libraryTracks: [LibraryTrack], to trackListId: UUID) throws -> Bool {
        guard !libraryTracks.isEmpty else { return true }

        var currentTracks = TrackListManager.shared.loadTracks(for: trackListId)
        let existingIds = Set(currentTracks.map(\.id))

        let newTracks = libraryTracks
            .filter { !existingIds.contains($0.id) }
            .map { Track(libraryTrack: $0) }

        guard !newTracks.isEmpty else { return true }

        currentTracks.append(contentsOf: newTracks)
        guard TrackListManager.shared.saveTracks(currentTracks, for: trackListId) else {
            throw TrackListStorageError.saveFailed(trackListId: trackListId)
        }

        return true
    }
    
    // MARK: - Удаление и переименование
    
    /// Удаляет плейлист по ID: треки + мета
    func deleteTrackList(id: UUID) {
        // Удаляем JSON-файл с треками
        TrackListManager.shared.deleteTracksFile(for: id)
        
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
        persistTrackListMetas(metas)
    }
    
    
    // MARK: - Сохранение всех треклистов (массово)
    
    /// Сохраняет все треклисты (отдельно JSON с треками и tracklists.json с мета)
    func saveTrackLists(_ trackLists: [TrackList]) {
        var didSaveTracks = false

        for list in trackLists {
            let didSave = TrackListManager.shared.saveTracks(
                list.tracks,
                for: list.id,
                postTrackListsDidChange: false
            )
            didSaveTracks = didSaveTracks || didSave
        }
        
        let metas = trackLists.map {
            TrackListMeta(id: $0.id, name: $0.name, createdAt: $0.createdAt)
        }
        
        let didSaveMetas = persistTrackListMetas(metas, postDidChange: false)
        if didSaveTracks || didSaveMetas {
            postTrackListsDidChange()
        }
        
        print("✅ Все треклисты сохранены (треки + мета)")
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

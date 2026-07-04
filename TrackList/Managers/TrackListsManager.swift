//
//  TrackListsManager.swift
//  TrackList
//
//  Менеджер для списка всех треклистов.
//  Отвечает за работу с SQLite-хранилищем треклистов:
//  - создание / удаление / переименование треклистов
//  - сохранение и загрузка списка TrackListMeta
//
//  Created by Pavel Fomin on 07.11.2025.
//

import Foundation

// Алиас фиксирует внешнюю модель метаинформации до объявления вложенного alias manager-а.
typealias TrackListsManagerTrackListMeta = TrackListMeta

final class TrackListsManager {
    
    static let shared = TrackListsManager()
    private let databaseStore: TrackListDatabaseStore

    private init() {
        do {
            self.databaseStore = try TrackListDatabaseStore()
        } catch {
            preconditionFailure("Не удалось создать TrackListDatabaseStore: \(error)")
        }
    }
    
    
    // MARK: - Модель метаинформации
    
    /// Совместимость для старых обращений TrackListsManager.TrackListMeta.
    typealias TrackListMeta = TrackListsManagerTrackListMeta
    
    
    // MARK: - Метаданные SQLite
    
    /// Загружает список всех треклистов из SQLite.
    func loadTrackListMetas() throws -> [TrackListMeta] {
        do {
            return try databaseStore.fetchMetas()
        } catch let appError as AppError {
            throw appError
        } catch {
            PersistentLogger.log("❌ TrackListsManager: SQLite load metas failed error=\(error)")
            throw AppError.trackListLoadFailed
        }
    }

    private func loadTrackListMetasOrEmpty() -> [TrackListMeta] {
        (try? loadTrackListMetas()) ?? []
    }
    
    /// Сохраняет список всех треклистов в SQLite.
    func saveTrackListMetas(_ metas: [TrackListMeta]) throws {
        let trackLists = try metas.map { meta in
            let tracks = try TrackListManager.shared.loadTracks(for: meta.id)
            return TrackList(
                id: meta.id,
                name: meta.name,
                createdAt: meta.createdAt,
                tracks: tracks
            )
        }

        try saveTrackLists(trackLists)
    }

    private func postTrackListsDidChange() {
        NotificationCenter.default.post(
            name: .trackListsDidChange,
            object: nil
        )
    }
    
    /// Проверяет, существует ли треклист с указанным ID.
    func trackListExists(id: UUID) -> Bool {
        do {
            return try databaseStore.exists(id: id)
        } catch {
            PersistentLogger.log("⚠️ TrackListsManager: SQLite exists failed id=\(id) error=\(error)")
            return false
        }
    }
    
    
    // MARK: - Создание треклистов

    // Базовый метод создания треклиста.
    /// Используется всеми сценариями создания (из фонотеки, из шита и т.д.).
    @discardableResult
    private func createTrackListInternal(tracks: [Track], name: String) throws -> TrackList {
        guard TrackListManager.shared.validateName(name) else {
            throw AppError.trackListNameInvalid
        }

        let id = UUID()
        let createdAt = Date()
        let trackList = try databaseStore.createTrackList(
            id: id,
            name: name,
            createdAt: createdAt,
            tracks: tracks
        )

        postTrackListsDidChange()
        return trackList
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

    // Сохраняет один TrackListMeta в SQLite.
    func saveTrackListMeta(_ meta: TrackListMeta) throws {
        try databaseStore.saveMeta(meta)
        postTrackListsDidChange()
    }

    // MARK: - Добавление треков

    /// Добавляет треки из фонотеки в существующий треклист.
    /// Повторное добавление одного и того же трека разрешено.
    @discardableResult
    func addTracks(_ libraryTracks: [LibraryTrack], to trackListId: UUID) throws -> Bool {
        guard !libraryTracks.isEmpty else { return true }

        // Конвертация остаётся на уровне manager-а списка треклистов,
        // а сохранение одного треклиста делегируется TrackListManager.
        let newTracks = libraryTracks.map { Track(libraryTrack: $0) }
        try TrackListManager.shared.addTracks(newTracks, to: trackListId)

        return true
    }
    
    // MARK: - Удаление и переименование
    
    /// Удаляет плейлист по ID: строки треклиста + мета.
    func deleteTrackList(id: UUID) throws {
        try databaseStore.deleteTrackList(id: id)
        postTrackListsDidChange()
        print("🗑️ Треклист \(id) удалён")
    }
    
    /// Переименовывает треклист по ID.
    func renameTrackList(id: UUID, to newName: String) throws {
        guard TrackListManager.shared.validateName(newName) else {
            throw AppError.trackListNameInvalid
        }

        try databaseStore.renameTrackList(id: id, to: newName)
        postTrackListsDidChange()
    }
    
    
    // MARK: - Сохранение всех треклистов (массово)
    
    /// Сохраняет все треклисты в SQLite.
    func saveTrackLists(_ trackLists: [TrackList]) throws {
        do {
            try databaseStore.replaceTrackLists(trackLists)
            postTrackListsDidChange()
            print("✅ Все треклисты сохранены в SQLite")
        } catch let appError as AppError {
            throw appError
        } catch {
            PersistentLogger.log("❌ TrackListsManager: SQLite saveTrackLists failed error=\(error)")
            throw AppError.trackListSaveFailed
        }
    }
    
    
    // MARK: - Отладка
    
    /// Выводит все треклисты и их содержимое в консоль
    func printTrackLists() {
        let metas = loadTrackListMetasOrEmpty()
        print("\n===== СОДЕРЖИМОЕ ВСЕХ ТРЕКЛИСТОВ =====")
        
        for meta in metas {
            let tracks = (try? TrackListManager.shared.loadTracks(for: meta.id)) ?? []
            print("Плейлист: \(meta.name), ID: \(meta.id)")
            for track in tracks {
                print("— \(track.fileName) (\(track.artist ?? "неизвестный артист") — \(track.title ?? "неизвестный трек")), duration: \(track.duration)")
            }
        }
    }
}

// MARK: - TrackListsManaging

extension TrackListsManager: TrackListsManaging {}

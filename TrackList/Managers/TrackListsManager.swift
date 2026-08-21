//
//  TrackListsManager.swift
//  TrackList
//
//  Менеджер для списка всех треклистов.
//  Отвечает за работу с SQLite-хранилищем треклистов:
//  - создание / удаление / переименование треклистов
//  - сохранение и загрузка списка TrackListMeta
//  - гарантия существования системного треклиста
//
//  Created by Pavel Fomin on 07.11.2025.
//

import Foundation

@MainActor
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

    /// Инициализатор для изолированных сценариев и тестов с переданным SQLite-фасадом.
    init(databaseStore: TrackListDatabaseStore) {
        self.databaseStore = databaseStore
    }
    
    
    // MARK: - Метаданные SQLite
    
    /// Загружает список всех треклистов из SQLite.
    func loadTrackListMetas() throws -> [TrackListMeta] {
        do {
            return try databaseStore.fetchMetas()
        } catch {
            PersistentLogger.log("❌ TrackListsManager: SQLite load metas failed error=\(error)")
            throw AppError.trackListLoadFailed
        }
    }

    /// Гарантирует наличие единственного активного системного треклиста «Избранное».
    /// Название используется только при первом создании и никогда не участвует в поиске системного треклиста.
    func ensureFavoritesTrackList() throws -> TrackListMeta {
        var didChangeTrackLists = false
        var badgeIndexChanges: [TrackListBadgeIndexChange] = []

        do {
            let favorites = try databaseStore.transaction {
                let activeMetas = try databaseStore.fetchActiveMetas(kind: .favorites)
                let deletedMetas = try databaseStore.fetchDeletedMetas(kind: .favorites)
                let candidates = makeFavoritesCandidates(
                    activeMetas: activeMetas,
                    deletedMetas: deletedMetas
                )

                guard let primary = candidates.first else {
                    let createdAt = Date()
                    let created = try databaseStore.createTrackList(
                        id: UUID(),
                        name: "Избранное",
                        kind: .favorites,
                        createdAt: createdAt,
                        tracks: []
                    )
                    didChangeTrackLists = true
                    badgeIndexChanges.append(.trackListRelationsReplaced(created))

                    return TrackListMeta(
                        id: created.id,
                        name: created.name,
                        createdAt: created.createdAt,
                        kind: created.kind
                    )
                }

                let duplicateActiveMetas = activeMetas.filter { $0.id != primary.meta.id }
                for duplicate in duplicateActiveMetas {
                    try logFavoritesDuplicateIfNeeded(duplicate)
                    try databaseStore.markTrackListDeleted(
                        id: duplicate.id,
                        updatedAt: Date()
                    )
                    didChangeTrackLists = true
                    badgeIndexChanges.append(.trackListDeleted(duplicate.id))
                }

                if primary.isActive == false {
                    try databaseStore.restoreTrackList(
                        id: primary.meta.id,
                        updatedAt: Date()
                    )
                    didChangeTrackLists = true
                    badgeIndexChanges.append(.trackListRelationsReloadRequested(primary.meta.id))
                }

                return primary.meta
            }

            if didChangeTrackLists {
                for change in badgeIndexChanges {
                    NotificationCenter.default.post(
                        name: .trackListBadgeIndexDidChange,
                        object: change
                    )
                }
                publishTrackListsDidChange()
            }

            return favorites
        } catch {
            PersistentLogger.log("TrackListsManager: не удалось гарантировать системный треклист «Избранное»: \(error)")
            throw AppError.trackListSaveFailed
        }
    }

    /// Возвращает активный системный треклист без создания новой записи.
    func favoritesTrackList() throws -> TrackListMeta? {
        do {
            let activeMetas = try databaseStore.fetchActiveMetas(kind: .favorites)
            return makeFavoritesCandidates(
                activeMetas: activeMetas,
                deletedMetas: []
            ).first?.meta
        } catch {
            PersistentLogger.log("TrackListsManager: не удалось загрузить системный треклист «Избранное»: \(error)")
            throw AppError.trackListLoadFailed
        }
    }

    /// Публикует invalidation после завершённой mutation, чтобы владельцы feature-state загрузили новый снимок.
    func publishTrackListsDidChange() {
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
    private func createTrackListInternal(
        tracks: [Track],
        name: String,
        kind: TrackListKind
    ) throws -> TrackList {
        guard TrackListManager.shared.validateName(name) else {
            throw AppError.trackListNameInvalid
        }

        let id = UUID()
        let createdAt = Date()

        do {
            // Создаём метаданные и строки треклиста одним вызовом фасада.
            let created = try databaseStore.createTrackList(
                id: id,
                name: name,
                kind: kind,
                createdAt: createdAt,
                tracks: tracks
            )
            NotificationCenter.default.post(
                name: .trackListBadgeIndexDidChange,
                object: TrackListBadgeIndexChange.trackListRelationsReplaced(created)
            )
            NotificationCenter.default.post(
                name: .trackListTracksDidChange,
                object: id
            )
            publishTrackListsDidChange()
            return created
        } catch {
            throw AppError.trackListSaveFailed
        }
    }

    // Создаёт новый треклист с авто-именем по дате ("dd.MM.yy, HH:mm")
    @discardableResult
    func createTrackList(from tracks: [Track]) throws -> TrackList {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy, HH:mm"
        let name = formatter.string(from: Date())
        
        return try createTrackListInternal(
            tracks: tracks,
            name: name,
            kind: .regular
        )
    }

    // Создаёт треклист с заданным именем (используется для ручного ввода)
    @discardableResult
    func createTrackList(from tracks: [Track], withName name: String) throws -> TrackList {
        return try createTrackListInternal(
            tracks: tracks,
            name: name,
            kind: .regular
        )
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

    // MARK: - Добавление треков

    /// Добавляет треки из фонотеки в существующий треклист.
    /// Повторное добавление одного и того же трека разрешено.
    @discardableResult
    func addTracks(_ libraryTracks: [LibraryTrack], to trackListId: UUID) throws -> TrackList {
        guard !libraryTracks.isEmpty else {
            return try TrackListManager.shared.getTrackListById(trackListId)
        }

        // Конвертация остаётся на уровне manager-а списка треклистов,
        // а сохранение строк делегируется TrackListManager.
        let newTracks = libraryTracks.map { Track(libraryTrack: $0) }
        return try TrackListManager.shared.addTracks(newTracks, to: trackListId)
    }
    
    // MARK: - Удаление и переименование
    
    /// Удаляет плейлист по ID: строки треклиста + мета.
    func deleteTrackList(id: UUID) throws {
        do {
            let meta = try databaseStore.fetchMeta(id: id)
            guard meta.kind.canDelete else {
                throw AppError.trackListDeletionNotAllowed
            }

            try databaseStore.deleteTrackList(id: id)
            NotificationCenter.default.post(
                name: .trackListBadgeIndexDidChange,
                object: TrackListBadgeIndexChange.trackListDeleted(id)
            )
            publishTrackListsDidChange()
        } catch let appError as AppError {
            throw appError
        } catch TrackListDatabaseStoreError.trackListNotFound {
            throw AppError.trackListNotFound
        } catch {
            throw AppError.trackListSaveFailed
        }

        print("🗑️ Треклист \(id) удалён")
    }

    /// Переименовывает треклист по ID.
    func renameTrackList(id: UUID, to newName: String) throws {
        do {
            let meta = try databaseStore.fetchMeta(id: id)
            guard meta.kind.canRename else {
                throw AppError.trackListRenameNotAllowed
            }
            guard TrackListManager.shared.validateName(newName) else {
                throw AppError.trackListNameInvalid
            }

            try databaseStore.renameTrackList(id: id, to: newName)
            NotificationCenter.default.post(
                name: .trackListBadgeIndexDidChange,
                object: TrackListBadgeIndexChange.trackListMetadataChanged(
                    TrackListMeta(
                        id: meta.id,
                        name: newName,
                        createdAt: meta.createdAt,
                        kind: meta.kind
                    )
                )
            )
            publishTrackListsDidChange()
        } catch let appError as AppError {
            throw appError
        } catch TrackListDatabaseStoreError.trackListNotFound {
            throw AppError.trackListNotFound
        } catch {
            throw AppError.trackListSaveFailed
        }
    }

    /// Сохраняет порядок обычных треклистов и сообщает экранам об изменении.
    func updateTrackListsOrder(_ orderedIds: [UUID]) throws {
        do {
            try databaseStore.updateDisplayedTrackListsOrder(orderedIds)
            publishTrackListsDidChange()
        } catch let appError as AppError {
            throw appError
        } catch TrackListDatabaseStoreError.trackListNotFound {
            throw AppError.trackListNotFound
        } catch {
            throw AppError.trackListSaveFailed
        }
    }

    // MARK: - Системный треклист

    /// Описывает кандидата на роль единственного системного треклиста вместе с его активностью.
    private struct FavoritesCandidate {
        let meta: TrackListMeta
        let isActive: Bool
    }

    /// Расставляет приоритеты: активная запись, затем более ранняя дата создания и стабильное сравнение UUID.
    private func makeFavoritesCandidates(
        activeMetas: [TrackListMeta],
        deletedMetas: [TrackListMeta]
    ) -> [FavoritesCandidate] {
        (activeMetas.map { FavoritesCandidate(meta: $0, isActive: true) } +
         deletedMetas.map { FavoritesCandidate(meta: $0, isActive: false) })
            .sorted { lhs, rhs in
                if lhs.isActive != rhs.isActive {
                    return lhs.isActive
                }
                if lhs.meta.createdAt != rhs.meta.createdAt {
                    return lhs.meta.createdAt < rhs.meta.createdAt
                }
                return lhs.meta.id.uuidString < rhs.meta.id.uuidString
            }
    }

    /// Фиксирует отладочную диагностику перед логическим удалением лишней системной записи с сохранёнными треками.
    private func logFavoritesDuplicateIfNeeded(_ meta: TrackListMeta) throws {
        #if DEBUG
        let tracksCount = try databaseStore.fetchTracks(for: meta.id).count
        guard tracksCount > 0 else {
            return
        }

        PersistentLogger.log(
            "TrackListsManager: лишний системный треклист «Избранное» id=\(meta.id) " +
            "помечен удалённым вместе с \(tracksCount) строками треков без объединения"
        )
        #endif
    }
}

// MARK: - TrackListsManaging

extension TrackListsManager: TrackListsManaging {}

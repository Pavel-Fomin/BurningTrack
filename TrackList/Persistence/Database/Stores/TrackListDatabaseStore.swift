//
//  TrackListDatabaseStore.swift
//  TrackList
//
//  Фасад SQLite-хранилища пользовательских треклистов.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Ошибки фасада треклистов, которые manager-слой преобразует в пользовательские AppError.
enum TrackListDatabaseStoreError: Error {
    case trackListNotFound(UUID)
}

// Фасад треклистов скрывает SQLite-модели и низкоуровневые Store от manager-слоя.
final class TrackListDatabaseStore {
    private let executor: DatabaseExecutor
    private let trackListStore: any TrackListDatabaseReading & TrackListDatabaseWriting
    private let trackStore: any TrackListTrackDatabaseReading & TrackListTrackDatabaseWriting

    init(executor: DatabaseExecutor) {
        self.executor = executor
        self.trackListStore = SQLiteTrackListStore(executor: executor)
        self.trackStore = SQLiteTrackListTrackStore(executor: executor)
    }

    convenience init(database: AppDatabase = .shared) throws {
        try self.init(executor: database.databaseExecutor())
    }

    // MARK: - Read

    /// Возвращает метаданные активных треклистов как бизнес-модели.
    func fetchMetas() throws -> [TrackListMeta] {
        try fetchActiveMetaModels()
            .map(TrackListMetaDatabaseMapper.trackListMeta)
    }

    /// Возвращает треклист вместе с его строками, сохраняя порядок по position.
    func fetchTrackList(id: UUID) throws -> TrackList {
        guard let metaModel = try activeMetaModel(id: id) else {
            throw TrackListDatabaseStoreError.trackListNotFound(id)
        }

        let tracks = try fetchTracksDirect(for: id)
        let meta = TrackListMetaDatabaseMapper.trackListMeta(from: metaModel)

        return TrackList(
            id: meta.id,
            name: meta.name,
            createdAt: meta.createdAt,
            tracks: tracks
        )
    }

    /// Возвращает строки одного треклиста без раскрытия SQLite-моделей верхним слоям.
    func fetchTracks(for id: UUID) throws -> [Track] {
        guard try activeMetaModel(id: id) != nil else {
            throw TrackListDatabaseStoreError.trackListNotFound(id)
        }

        return try fetchTracksDirect(for: id)
    }

    /// Проверяет существование активного треклиста.
    func exists(id: UUID) throws -> Bool {
        try activeMetaModel(id: id) != nil
    }

    // MARK: - Write

    /// Создаёт треклист и все его строки в одной транзакции.
    @discardableResult
    func createTrackList(
        id: UUID,
        name: String,
        createdAt: Date,
        tracks: [Track]
    ) throws -> TrackList {
        let trackList = TrackList(
            id: id,
            name: name,
            createdAt: createdAt,
            tracks: tracks
        )

        try executor.transaction { _ in
            try saveMetaDirect(
                TrackListMeta(id: id, name: name, createdAt: createdAt),
                updatedAt: createdAt
            )
            try replaceTracksDirect(tracks, for: id, updatedAt: createdAt)
        }

        return trackList
    }

    /// Заменяет строки треклиста и обновляет дату изменения метаданных.
    func replaceTracks(_ tracks: [Track], for id: UUID) throws {
        let updatedAt = Date()
        try executor.transaction { _ in
            guard var metaModel = try activeMetaModel(id: id) else {
                throw TrackListDatabaseStoreError.trackListNotFound(id)
            }

            metaModel.updatedAt = updatedAt
            try trackListStore.upsert(metaModel)
            try replaceTracksDirect(tracks, for: id, updatedAt: updatedAt)
        }
    }

    /// Полностью заменяет набор треклистов, сохраняя строки каждого списка.
    func replaceTrackLists(_ trackLists: [TrackList]) throws {
        try replaceTrackListsDirect(trackLists)
    }

    /// Создаёт или обновляет метаданные одного треклиста.
    func saveMeta(_ meta: TrackListMeta) throws {
        try saveMetaDirect(meta, updatedAt: Date())
    }

    /// Переименовывает активный треклист без изменения состава треков.
    func renameTrackList(id: UUID, to newName: String) throws {
        guard var model = try activeMetaModel(id: id) else {
            throw TrackListDatabaseStoreError.trackListNotFound(id)
        }

        model.name = newName
        model.updatedAt = Date()
        try trackListStore.upsert(model)
    }

    /// Удаляет треклист; дочерние строки удаляются каскадом по внешнему ключу.
    func deleteTrackList(id: UUID) throws {
        guard try activeMetaModel(id: id) != nil else {
            throw TrackListDatabaseStoreError.trackListNotFound(id)
        }

        try trackListStore.delete(id: id)
    }

    // MARK: - Internal Mapping

    /// Возвращает активные SQLite-модели метаданных.
    private func fetchActiveMetaModels() throws -> [TrackListDatabaseModel] {
        try trackListStore.fetchAll()
            .filter { $0.isDeleted == false }
    }

    /// Возвращает активную SQLite-модель метаданных по id.
    private func activeMetaModel(id: UUID) throws -> TrackListDatabaseModel? {
        guard let model = try trackListStore.fetch(id: id), model.isDeleted == false else {
            return nil
        }

        return model
    }

    /// Возвращает строки треклиста из SQLite.
    private func fetchTracksDirect(for id: UUID) throws -> [Track] {
        try trackStore.fetchAll(trackListId: id)
            .map(TrackListTrackDatabaseMapper.track)
    }

    /// Сохраняет метаданные треклиста в SQLite, не теряя служебный порядок сортировки.
    private func saveMetaDirect(
        _ meta: TrackListMeta,
        updatedAt: Date
    ) throws {
        let existing = try trackListStore.fetch(id: meta.id)
        let model = TrackListDatabaseModel(
            id: meta.id,
            name: meta.name,
            createdAt: meta.createdAt,
            updatedAt: updatedAt,
            sortOrder: existing?.sortOrder,
            isDeleted: false
        )

        try trackListStore.upsert(model)
    }

    /// Заменяет строки одного треклиста в SQLite.
    private func replaceTracksDirect(
        _ tracks: [Track],
        for id: UUID,
        updatedAt: Date
    ) throws {
        let previousRows = try trackStore.fetchAll(trackListId: id)
        let createdAtByRowId = Dictionary(
            uniqueKeysWithValues: previousRows.map { ($0.id, $0.createdAt) }
        )

        let models = tracks.enumerated().map { position, track in
            TrackListTrackDatabaseMapper.databaseModel(
                from: track,
                trackListId: id,
                position: position,
                createdAt: createdAtByRowId[track.id] ?? updatedAt
            )
        }

        try trackStore.replaceAll(models, forTrackListId: id)
    }

    /// Заменяет все треклисты в SQLite.
    private func replaceTrackListsDirect(_ trackLists: [TrackList]) throws {
        let updatedAt = Date()
        let incomingIds = Set(trackLists.map(\.id))

        try executor.transaction { _ in
            let existingIds = try trackListStore.fetchAll().map(\.id)
            for id in existingIds where incomingIds.contains(id) == false {
                try trackListStore.delete(id: id)
            }

            for list in trackLists {
                try saveMetaDirect(
                    TrackListMeta(
                        id: list.id,
                        name: list.name,
                        createdAt: list.createdAt
                    ),
                    updatedAt: updatedAt
                )
                try replaceTracksDirect(
                    list.tracks,
                    for: list.id,
                    updatedAt: updatedAt
                )
            }
        }
    }
}

//
//  TrackListDatabaseStore.swift
//  TrackList
//
//  Единый Store треклистов поверх SQLite.
//  Отдаёт наружу бизнес-модели треклистов и скрывает DatabaseModel.
//
//  Created by Pavel Fomin on 05.07.2026.
//

import Foundation

// Фасад треклистов скрывает низкоуровневые SQLite Store от Manager и верхних слоёв.
final class TrackListDatabaseStore {
    private let trackListsStore: any TrackListDatabaseReading & TrackListDatabaseWriting
    private let trackListTracksStore: any TrackListTrackDatabaseReading & TrackListTrackDatabaseWriting
    private var didCheckLegacyMigration = false

    init(
        trackListsStore: any TrackListDatabaseReading & TrackListDatabaseWriting,
        trackListTracksStore: any TrackListTrackDatabaseReading & TrackListTrackDatabaseWriting
    ) {
        self.trackListsStore = trackListsStore
        self.trackListTracksStore = trackListTracksStore
    }

    convenience init() throws {
        try self.init(
            trackListsStore: SQLiteTrackListStore(),
            trackListTracksStore: SQLiteTrackListTrackStore()
        )
    }

    // MARK: - Legacy migration

    /// Один раз переносит старые JSON-треклисты в SQLite, если таблица tracklists ещё пустая.
    /// После успешной миграции рабочие операции используют только SQLite.
    func migrateLegacyJSONIfNeeded() throws {
        guard !didCheckLegacyMigration else { return }
        didCheckLegacyMigration = true

        let existingModels = try trackListsStore.fetchAll()
        guard existingModels.isEmpty else { return }

        let legacyTrackLists = try LegacyTrackListJSONReader.loadTrackLists()
        guard !legacyTrackLists.isEmpty else { return }

        try replaceTrackLists(legacyTrackLists)
        PersistentLogger.log("✅ TrackListDatabaseStore: migrated legacy JSON tracklists=\(legacyTrackLists.count)")
    }

    // MARK: - TrackList meta

    /// Возвращает метаинформацию треклистов как бизнес-модели.
    func fetchMetas() throws -> [TrackListMeta] {
        try migrateLegacyJSONIfNeeded()

        return try trackListsStore.fetchAll()
            .filter { !$0.isDeleted }
            .map(TrackListMetaDatabaseMapper.trackListMeta)
    }

    /// Проверяет наличие активного треклиста.
    func exists(id: UUID) throws -> Bool {
        try migrateLegacyJSONIfNeeded()

        guard let model = try trackListsStore.fetch(id: id) else {
            return false
        }
        return !model.isDeleted
    }

    /// Создаёт или обновляет метаинформацию треклиста.
    func saveMeta(_ meta: TrackListMeta) throws {
        try migrateLegacyJSONIfNeeded()

        let now = Date()
        let existing = try trackListsStore.fetch(id: meta.id)
        let model = TrackListDatabaseModel(
            id: meta.id,
            name: meta.name,
            createdAt: meta.createdAt,
            updatedAt: now,
            sortOrder: existing?.sortOrder,
            isDeleted: false
        )

        try trackListsStore.upsert(model)
    }

    /// Переименовывает треклист без раскрытия SQLite-модели наружу.
    func renameTrackList(id: UUID, to newName: String) throws {
        try migrateLegacyJSONIfNeeded()

        guard var model = try trackListsStore.fetch(id: id), !model.isDeleted else {
            throw AppError.trackListNotFound
        }

        model.name = newName
        model.updatedAt = Date()
        try trackListsStore.update(model)
    }

    /// Удаляет треклист и строки его содержимого.
    func deleteTrackList(id: UUID) throws {
        try migrateLegacyJSONIfNeeded()

        guard let model = try trackListsStore.fetch(id: id), !model.isDeleted else {
            throw AppError.trackListNotFound
        }

        try trackListTracksStore.replaceAll([], forTrackListId: id)
        try trackListsStore.delete(id: id)
    }

    // MARK: - Full TrackList

    /// Возвращает полный треклист с треками.
    func fetchTrackList(id: UUID) throws -> TrackList {
        try migrateLegacyJSONIfNeeded()

        guard let model = try trackListsStore.fetch(id: id), !model.isDeleted else {
            throw AppError.trackListNotFound
        }

        return TrackList(
            id: model.id,
            name: model.name,
            createdAt: model.createdAt,
            tracks: try fetchTracksWithoutMigration(for: id)
        )
    }

    /// Возвращает треки конкретного треклиста как бизнес-модели.
    func fetchTracks(for id: UUID) throws -> [Track] {
        try migrateLegacyJSONIfNeeded()
        return try fetchTracksWithoutMigration(for: id)
    }

    /// Создаёт новый треклист и его строки в SQLite.
    func createTrackList(
        id: UUID,
        name: String,
        createdAt: Date,
        tracks: [Track]
    ) throws -> TrackList {
        try migrateLegacyJSONIfNeeded()

        let model = TrackListDatabaseModel(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: createdAt,
            sortOrder: nil,
            isDeleted: false
        )

        try trackListsStore.insert(model)
        try replaceTracksWithoutMigration(tracks, for: id)

        return TrackList(
            id: id,
            name: name,
            createdAt: createdAt,
            tracks: tracks
        )
    }

    /// Атомарно заменяет содержимое одного треклиста.
    func replaceTracks(_ tracks: [Track], for id: UUID) throws {
        try migrateLegacyJSONIfNeeded()
        try replaceTracksWithoutMigration(tracks, for: id)
    }

    /// Заменяет набор треклистов на переданный список бизнес-моделей.
    /// Треклисты, которых нет в новом списке, удаляются вместе со строками содержимого.
    func replaceTrackLists(_ trackLists: [TrackList]) throws {
        let incomingIds = Set(trackLists.map(\.id))
        let existingModels = try trackListsStore.fetchAll()

        for model in existingModels where !incomingIds.contains(model.id) {
            try trackListTracksStore.replaceAll([], forTrackListId: model.id)
            try trackListsStore.delete(id: model.id)
        }

        for list in trackLists {
            let existing = try trackListsStore.fetch(id: list.id)
            let model = TrackListDatabaseModel(
                id: list.id,
                name: list.name,
                createdAt: list.createdAt,
                updatedAt: Date(),
                sortOrder: existing?.sortOrder,
                isDeleted: false
            )
            try trackListsStore.upsert(model)
            try replaceTracksWithoutMigration(list.tracks, for: list.id)
        }
    }

    // MARK: - Private helpers

    private func fetchTracksWithoutMigration(for id: UUID) throws -> [Track] {
        try trackListTracksStore.fetchAll(trackListId: id)
            .map(TrackListTrackDatabaseMapper.track)
    }

    private func replaceTracksWithoutMigration(_ tracks: [Track], for id: UUID) throws {
        let now = Date()
        let models = tracks.enumerated().map { index, track in
            TrackListTrackDatabaseMapper.databaseModel(
                from: track,
                trackListId: id,
                position: index,
                createdAt: now
            )
        }

        try trackListTracksStore.replaceAll(models, forTrackListId: id)
    }
}

// MARK: - Legacy JSON reader

private enum LegacyTrackListJSONReader {
    private static var documentsDirectory: URL? {
        FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first
    }

    private static var metasURL: URL? {
        documentsDirectory?.appendingPathComponent("tracklists.json")
    }

    private static func urlForTrackList(id: UUID) -> URL? {
        documentsDirectory?.appendingPathComponent("tracklist_\(id.uuidString).json")
    }

    /// Читает старый JSON-формат только для одноразовой миграции в SQLite.
    static func loadTrackLists() throws -> [TrackList] {
        let metas = try loadMetas()

        return try metas.map { meta in
            TrackList(
                id: meta.id,
                name: meta.name,
                createdAt: meta.createdAt,
                tracks: try loadTracks(for: meta.id)
            )
        }
    }

    private static func loadMetas() throws -> [TrackListMeta] {
        guard let url = metasURL else {
            throw AppError.trackListLoadFailed
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([TrackListMeta].self, from: data)
        } catch {
            throw AppError.trackListLoadFailed
        }
    }

    private static func loadTracks(for id: UUID) throws -> [Track] {
        guard let url = urlForTrackList(id: id) else {
            throw AppError.trackListLoadFailed
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([Track].self, from: data)
        } catch {
            throw AppError.trackListLoadFailed
        }
    }
}

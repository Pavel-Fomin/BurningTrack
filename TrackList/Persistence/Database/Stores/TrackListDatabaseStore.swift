//
//  TrackListDatabaseStore.swift
//  TrackList
//
//  Фасад SQLite-хранилища треклистов.
//
//  Created by Pavel Fomin on 05.07.2026.
//

import Foundation

// Ошибки фасада треклистов, доступные manager-слою для преобразования в пользовательские AppError.
enum TrackListDatabaseStoreError: Error {
    case trackListNotFound(UUID)
    /// Полное сохранение не может изменить защищённые метаданные системного треклиста.
    case protectedTrackListMetadataModification(UUID)
    /// Передан неполный, повторяющийся или содержащий системный треклист пользовательский порядок.
    case invalidRegularTrackListsOrder
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

    // MARK: - Чтение

    /// Возвращает метаданные активных треклистов как бизнес-модели.
    func fetchMetas() throws -> [TrackListMeta] {
        try fetchActiveMetaModels()
            .map(TrackListMetaDatabaseMapper.trackListMeta)
    }

    /// Возвращает метаданные активного треклиста по идентификатору.
    func fetchMeta(id: UUID) throws -> TrackListMeta {
        guard let metaModel = try activeMetaModel(id: id) else {
            throw TrackListDatabaseStoreError.trackListNotFound(id)
        }

        return TrackListMetaDatabaseMapper.trackListMeta(from: metaModel)
    }

    /// Возвращает метаданные активных треклистов указанного назначения.
    func fetchActiveMetas(kind: TrackListKind) throws -> [TrackListMeta] {
        try trackListStore.fetchAll()
            .filter {
                $0.isDeleted == false &&
                TrackListKindDatabaseMapper.trackListKind(from: $0.kind) == kind
            }
            .map(TrackListMetaDatabaseMapper.trackListMeta)
    }

    /// Возвращает метаданные логически удалённых треклистов указанного назначения.
    func fetchDeletedMetas(kind: TrackListKind) throws -> [TrackListMeta] {
        try trackListStore.fetchAll()
            .filter {
                $0.isDeleted &&
                TrackListKindDatabaseMapper.trackListKind(from: $0.kind) == kind
            }
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
            kind: meta.kind,
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

    // MARK: - Запись

    /// Создаёт треклист с заданным назначением и все его строки в одной транзакции.
    @discardableResult
    func createTrackList(
        id: UUID,
        name: String,
        kind: TrackListKind,
        createdAt: Date,
        tracks: [Track]
    ) throws -> TrackList {
        let trackList = TrackList(
            id: id,
            name: name,
            createdAt: createdAt,
            kind: kind,
            tracks: tracks
        )

        try executor.transaction { _ in
            if kind.canReorder {
                try shiftActiveRegularTrackListsDown(updatedAt: createdAt)
            }
            try trackListStore.upsert(
                TrackListDatabaseModel(
                    id: id,
                    name: name,
                    kind: TrackListKindDatabaseMapper.databaseKind(from: trackList.kind),
                    createdAt: createdAt,
                    updatedAt: createdAt,
                    sortOrder: 0,
                    isDeleted: false
                )
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

    /// Полностью заменяет переданные треклисты, сохраняя строки каждого списка и отсутствующий системный треклист.
    func replaceTrackLists(_ trackLists: [TrackList]) throws {
        try replaceTrackListsDirect(trackLists)
    }

    /// Создаёт или обновляет метаданные одного треклиста.
    func saveMeta(_ meta: TrackListMeta) throws {
        try validateMetadataWrite(meta)
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

    /// Помечает активный треклист удалённым, не затрагивая строки его треков.
    func markTrackListDeleted(id: UUID, updatedAt: Date) throws {
        guard try activeMetaModel(id: id) != nil else {
            throw TrackListDatabaseStoreError.trackListNotFound(id)
        }

        try trackListStore.markDeleted(id: id, updatedAt: updatedAt)
    }

    /// Восстанавливает ранее логически удалённый треклист с тем же идентификатором и составом треков.
    func restoreTrackList(id: UUID, updatedAt: Date) throws {
        guard var model = try trackListStore.fetch(id: id), model.isDeleted else {
            throw TrackListDatabaseStoreError.trackListNotFound(id)
        }

        model.isDeleted = false
        model.updatedAt = updatedAt
        try trackListStore.upsert(model)
    }

    /// Выполняет несколько операций фасада в одной SQLite-транзакции.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        try executor.transaction { _ in
            try body()
        }
    }

    /// Сохраняет порядок активных обычных треклистов в sort_order.
    func updateTrackListsOrder(_ orderedRegularIds: [UUID]) throws {
        let updatedAt = Date()
        let activeRegularModels = try fetchActiveMetaModels().filter {
            TrackListKindDatabaseMapper.trackListKind(from: $0.kind) == .regular
        }
        let activeRegularModelsByID = Dictionary(
            uniqueKeysWithValues: activeRegularModels.map { ($0.id, $0) }
        )
        let expectedRegularIds = Set(activeRegularModelsByID.keys)

        guard Set(orderedRegularIds).count == orderedRegularIds.count,
              Set(orderedRegularIds) == expectedRegularIds
        else {
            throw TrackListDatabaseStoreError.invalidRegularTrackListsOrder
        }

        try executor.transaction { _ in
            for (index, id) in orderedRegularIds.enumerated() {
                guard var model = activeRegularModelsByID[id] else {
                    throw TrackListDatabaseStoreError.invalidRegularTrackListsOrder
                }

                model.sortOrder = index
                model.updatedAt = updatedAt
                try trackListStore.upsert(model)
            }
        }
    }

    /// Проверяет полный порядок master-списка и сохраняет только позиции обычных треклистов.
    func updateDisplayedTrackListsOrder(_ orderedIds: [UUID]) throws {
        let metas = try fetchMetas()
        let metasByID = Dictionary(uniqueKeysWithValues: metas.map { ($0.id, $0) })
        let activeIDs = Set(metasByID.keys)

        if let unknownID = orderedIds.first(where: { metasByID[$0] == nil }) {
            throw TrackListDatabaseStoreError.trackListNotFound(unknownID)
        }

        guard Set(orderedIds).count == orderedIds.count,
              Set(orderedIds) == activeIDs
        else {
            throw AppError.trackListReorderNotAllowed
        }

        let orderedMetas = orderedIds.compactMap { metasByID[$0] }
        let favorites = metas.filter { $0.kind == .favorites }
        guard favorites.count == 1,
              orderedMetas.first?.kind == .favorites,
              orderedMetas.dropFirst().allSatisfy({ $0.kind == .regular })
        else {
            throw AppError.trackListReorderNotAllowed
        }

        try updateTrackListsOrder(
            orderedMetas
                .filter { $0.kind.canReorder }
                .map(\.id)
        )
    }

    // MARK: - Внутреннее сопоставление

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
        var model = TrackListMetaDatabaseMapper.databaseModel(
            from: meta,
            updatedAt: updatedAt
        )
        model.sortOrder = existing?.sortOrder

        try trackListStore.upsert(model)
    }

    /// Сдвигает активные обычные треклисты вниз перед вставкой нового обычного элемента наверх.
    private func shiftActiveRegularTrackListsDown(updatedAt: Date) throws {
        let activeModels = try fetchActiveMetaModels().filter {
            TrackListKindDatabaseMapper.trackListKind(from: $0.kind) == .regular
        }

        for (index, var model) in activeModels.enumerated() {
            // Текущий fetchAll-порядок становится базовым порядком для старых записей без sort_order.
            model.sortOrder = index + 1
            model.updatedAt = updatedAt
            try trackListStore.upsert(model)
        }
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
            let existingModels = try trackListStore.fetchAll()
            let existingModelsByID = Dictionary(
                uniqueKeysWithValues: existingModels.map { ($0.id, $0) }
            )

            for list in trackLists {
                try validateMetadataWrite(
                    TrackListMeta(
                        id: list.id,
                        name: list.name,
                        createdAt: list.createdAt,
                        kind: list.kind
                    ),
                    existingModel: existingModelsByID[list.id]
                )
            }

            for model in existingModels where incomingIds.contains(model.id) == false {
                guard TrackListKindDatabaseMapper.trackListKind(from: model.kind) != .favorites else {
                    continue
                }

                try trackListStore.delete(id: model.id)
            }

            for list in trackLists {
                try saveMetaDirect(
                    TrackListMeta(
                        id: list.id,
                        name: list.name,
                        createdAt: list.createdAt,
                        kind: list.kind
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

    /// Проверяет, что полное сохранение не меняет назначение или название защищённого треклиста.
    private func validateMetadataWrite(
        _ meta: TrackListMeta,
        existingModel: TrackListDatabaseModel? = nil
    ) throws {
        let resolvedExistingModel: TrackListDatabaseModel?
        if let existingModel {
            resolvedExistingModel = existingModel
        } else {
            resolvedExistingModel = try trackListStore.fetch(id: meta.id)
        }
        let incomingKind = TrackListKindDatabaseMapper.databaseKind(from: meta.kind)

        guard let resolvedExistingModel else {
            guard meta.kind != .favorites else {
                throw TrackListDatabaseStoreError.protectedTrackListMetadataModification(meta.id)
            }
            return
        }

        let existingKind = TrackListKindDatabaseMapper.trackListKind(from: resolvedExistingModel.kind)
        guard existingKind != .favorites else {
            guard incomingKind == resolvedExistingModel.kind, meta.name == resolvedExistingModel.name else {
                throw TrackListDatabaseStoreError.protectedTrackListMetadataModification(meta.id)
            }
            return
        }

        guard meta.kind != .favorites else {
            throw TrackListDatabaseStoreError.protectedTrackListMetadataModification(meta.id)
        }
    }
}

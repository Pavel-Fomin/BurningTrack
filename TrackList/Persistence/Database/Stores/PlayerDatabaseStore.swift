//
//  PlayerDatabaseStore.swift
//  TrackList
//
//  Единый Store плеера поверх SQLite.
//  Отдаёт наружу бизнес-модели плеера и скрывает DatabaseModel.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

// Фасад плеера скрывает низкоуровневые SQLite Store от Manager и верхних слоёв.
final class PlayerDatabaseStore {
    private let queueStore: any PlayerQueueDatabaseReading & PlayerQueueDatabaseWriting
    private let stateStore: any PlayerStateDatabaseReading & PlayerStateDatabaseWriting

    init(
        queueStore: any PlayerQueueDatabaseReading & PlayerQueueDatabaseWriting,
        stateStore: any PlayerStateDatabaseReading & PlayerStateDatabaseWriting
    ) {
        self.queueStore = queueStore
        self.stateStore = stateStore
    }

    convenience init() throws {
        try self.init(
            queueStore: SQLitePlayerQueueStore(),
            stateStore: SQLitePlayerStateStore()
        )
    }

    // MARK: - Queue

    /// Возвращает очередь плеера как бизнес-модели, без протаскивания SQLite-моделей выше Store.
    func fetchQueue() throws -> [PlayerTrack] {
        let models = try queueStore.fetchAll()
        return models.map(Self.makePlayerTrack)
    }

    /// Атомарно заменяет всю очередь плеера в таблице player_queue.
    func replaceQueue(_ tracks: [PlayerTrack]) throws {
        let models = tracks.enumerated().map { index, track in
            Self.makeQueueModel(
                from: track,
                position: index
            )
        }

        let savedState = try stateStore.fetch()

        try queueStore.replaceAll(models)

        // replaceAll удаляет старые строки очереди, поэтому SQLite может временно обнулить внешний ключ.
        // Если текущий элемент остался в новой очереди, возвращаем ссылку на единственную строку состояния.
        guard let savedState,
              let queueItemId = savedState.currentQueueItemId,
              models.contains(where: { $0.id == queueItemId }) else {
            return
        }

        try stateStore.upsert(savedState)
    }

    /// Очищает очередь плеера без раскрытия низкоуровневого Store наружу.
    func clearQueue() throws {
        try queueStore.replaceAll([])
    }

    // MARK: - State

    /// Возвращает сохранённое состояние плеера для будущего подключения восстановления playback-состояния.
    func fetchState() throws -> PlayerStateDatabaseModel? {
        try stateStore.fetch()
    }

    /// Сохраняет состояние плеера через единственную строку player_state.
    func saveState(_ state: PlayerStateDatabaseModel) throws {
        try stateStore.upsert(state)
    }

    /// Удаляет сохранённое состояние плеера.
    func clearState() throws {
        try stateStore.delete()
    }

    // MARK: - Mapping

    /// Создаёт SQLite-снимок элемента очереди из runtime-модели плеера.
    private static func makeQueueModel(
        from track: PlayerTrack,
        position: Int
    ) -> PlayerQueueItemDatabaseModel {
        PlayerQueueItemDatabaseModel(
            id: track.queueItemId,
            trackId: track.trackId,
            position: position,
            sourceSnapshot: TrackSourceDatabaseMapper.databaseSource(from: track.source),
            titleSnapshot: track.title,
            artistSnapshot: track.artist,
            albumSnapshot: track.album,
            durationSnapshot: track.duration,
            fileNameSnapshot: track.fileName,
            assetURLSnapshot: track.assetURL?.absoluteString,
            isAvailableSnapshot: track.isAvailable,
            createdAt: Date()
        )
    }

    /// Восстанавливает runtime-модель плеера из сохранённого SQLite-снимка очереди.
    private static func makePlayerTrack(
        from model: PlayerQueueItemDatabaseModel
    ) -> PlayerTrack {
        PlayerTrack(
            queueItemId: model.id,
            trackId: model.trackId,
            title: model.titleSnapshot,
            artist: model.artistSnapshot,
            album: model.albumSnapshot,
            artworkData: nil,
            duration: model.durationSnapshot ?? 0,
            fileName: model.fileNameSnapshot ?? "",
            isAvailable: model.isAvailableSnapshot,
            source: TrackSourceDatabaseMapper.trackSource(from: model.sourceSnapshot),
            assetURL: model.assetURLSnapshot.flatMap(URL.init(string:))
        )
    }
}

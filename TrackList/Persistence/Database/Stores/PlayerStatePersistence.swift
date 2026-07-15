//
//  PlayerStatePersistence.swift
//  TrackList
//
//  Компонент сохранения и загрузки текущего состояния плеера.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

/// Описывает операции постоянного состояния текущего трека без раскрытия SQLite-слоя.
protocol PlayerStatePersisting: AnyObject {
    /// Загружает единственное сохранённое состояние плеера.
    func loadState() throws -> PlayerStateDatabaseModel?

    /// Сохраняет выбранный трек как остановленный на нулевой позиции.
    func saveCurrentTrack(
        trackId: UUID,
        queueItemId: UUID?,
        duration: TimeInterval,
        playbackMode: PlaybackMode,
        contextSource: PlaybackContextSource
    ) throws

    /// Удаляет сохранённое состояние текущего трека.
    func clearState() throws
}

/// Реализует постоянное состояние плеера через существующий фасад PlayerDatabaseStore.
final class PlayerStatePersistence: PlayerStatePersisting {
    private static let stateID = 1

    private let databaseStore: PlayerDatabaseStore

    /// Создаёт компонент поверх переданного фасада базы данных.
    init(databaseStore: PlayerDatabaseStore) {
        self.databaseStore = databaseStore
    }

    /// Создаёт production-компонент поверх общей базы приложения.
    convenience init() throws {
        try self.init(databaseStore: PlayerDatabaseStore())
    }

    func loadState() throws -> PlayerStateDatabaseModel? {
        try databaseStore.fetchState()
    }

    func saveCurrentTrack(
        trackId: UUID,
        queueItemId: UUID?,
        duration: TimeInterval,
        playbackMode: PlaybackMode,
        contextSource: PlaybackContextSource = .playerQueue
    ) throws {
        let normalizedMode = playbackMode.normalized
        let state = PlayerStateDatabaseModel(
            id: Self.stateID,
            currentQueueItemId: queueItemId,
            currentTrackId: trackId,
            contextType: PlaybackContextSourceDatabaseMapper.databaseType(from: contextSource),
            contextId: PlaybackContextSourceDatabaseMapper.contextId(from: contextSource),
            collectionCategory: PlaybackContextSourceDatabaseMapper.collectionCategory(from: contextSource),
            collectionValue: PlaybackContextSourceDatabaseMapper.collectionValue(from: contextSource),
            collectionArtistKey: PlaybackContextSourceDatabaseMapper.collectionArtistKey(from: contextSource),
            playbackTime: 0,
            duration: duration.isFinite && duration > 0 ? duration : nil,
            isPlaying: false,
            repeatMode: databaseRepeatMode(from: normalizedMode.repeatMode),
            shuffleEnabled: normalizedMode.isShuffleEnabled,
            updatedAt: Date()
        )

        // Единственный идентификатор состояния задаётся здесь, поэтому повторные записи используют тот же upsert-ключ.
        try databaseStore.saveState(state)
    }

    func clearState() throws {
        try databaseStore.clearState()
    }

    /// Преобразует runtime-режим повтора в стабильное значение формата SQLite.
    private func databaseRepeatMode(
        from mode: PlaybackRepeatMode
    ) -> DatabaseRepeatMode {
        switch mode {
        case .off:
            return .off
        case .one:
            return .one
        case .all:
            return .all
        }
    }
}

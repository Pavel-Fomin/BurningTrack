//
//  MoveToFolderFlowProtocols.swift
//  TrackList
//
//  Узкие production-контракты Move To Folder feature-flow.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Загружает текущую папку локального трека для начального состояния move-flow.
protocol MoveToFolderTrackRegistryReading: Sendable {
    /// Возвращает SQLite entry трека, если он ещё существует в фонотеке.
    func entry(for id: UUID) async -> TrackRegistry.TrackEntry?
}

/// Выполняет существующие команды перемещения local-трека и копирования Purchased iTunes.
@MainActor
protocol MoveToFolderCommandExecuting {
    /// Перемещает локальный трек с сохранением проверки занятости файла.
    func moveTrack(
        trackId: UUID,
        toFolder folderID: UUID,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> MoveTrackCommandResult

    /// Копирует уже подготовленный iTunes-трек без TrackRegistry и file busy capability.
    func copyPurchasedITunesTrack(
        _ track: PurchasedITunesPlayableTrack,
        toFolder folderID: UUID
    ) async throws -> CopyPurchasedITunesTrackSuccess
}

// MARK: - Адаптеры production-слоя

extension TrackRegistry: MoveToFolderTrackRegistryReading {}

extension AppCommandExecutor: MoveToFolderCommandExecuting {}

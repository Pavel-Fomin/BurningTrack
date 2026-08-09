//
//  RenameTrackFileFlowProtocols.swift
//  TrackList
//
//  Узкие контракты зависимостей sheet-flow ручного переименования файла трека.
//
//  Created by Pavel Fomin on 08.08.2026.
//

import Foundation

/// Выполняет существующую команду сохранения изменений одного трека.
protocol RenameTrackFileCommandExecuting {
    /// Сохраняет новое имя файла вместе с согласованным post-update pipeline.
    func saveTrackEdits(
        trackId: UUID,
        newFileName: String,
        fileChanged: Bool,
        patch: TagWritePatch,
        tagsChanged: Bool,
        artworkAction: ArtworkWriteAction,
        artworkChanged: Bool,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> TrackEditsSavedSuccess
}

/// Маршрутизирует завершение sheet ручного переименования файла.
@MainActor
protocol RenameTrackFileRouting: AnyObject {
    /// Закрывает только route ручного переименования с переданной идентичностью.
    func dismissRenameTrackFile(_ routeID: UUID)
}

// MARK: - Production adapters

extension AppCommandExecutor: RenameTrackFileCommandExecuting {}

extension SheetManager: RenameTrackFileRouting {}

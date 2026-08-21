//
//  BatchFilenameRenameFlowProtocols.swift
//  TrackList
//
//  Узкие контракты зависимостей Batch Filename Rename.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Открывает и закрывает immutable route массового переименования через lifecycle SheetManager.
@MainActor
protocol BatchFilenameRenameRouting: AnyObject {
    /// Открывает новый feature-сеанс со снимком выбранных строк.
    func presentBatchFilenameRename(
        pendingAction: PendingBulkTrackAction,
        tracks: [BatchFilenameRenameTrackSeed]
    )
    /// Закрывает только route Batch Filename Rename с переданной идентичностью.
    func dismissBatchFilenameRename(_ routeID: UUID)
}

/// Загружает runtime metadata и сообщает progress без знания ViewModel и SwiftUI.
@MainActor
protocol BatchFilenameRenameMetadataLoading {
    /// Возвращает immutable подготовленные треки для route snapshot.
    func loadTracks(
        from seeds: [BatchFilenameRenameTrackSeed],
        progress: @escaping @MainActor @Sendable (Int, Int) -> Void
    ) async -> [BatchFilenameRenameTrack]
}

/// Выполняет существующий writer массового переименования файлов.
@MainActor
protocol BatchFilenameRenameCommandExecuting {
    /// Применяет готовые команды и передаёт progress каждой завершённой строки.
    func renameTrackFilesBatch(
        _ commands: [BatchFilenameRenameCommand],
        using fileBusyChecker: any TrackFileBusyChecking,
        progress: (@MainActor @Sendable (_ processed: Int, _ total: Int) -> Void)?
    ) async -> BatchFilenameRenameResult
}

// MARK: - Адаптеры production-слоя

extension BatchFilenameRenameMetadataLoader: BatchFilenameRenameMetadataLoading {}

extension AppCommandExecutor: BatchFilenameRenameCommandExecuting {}

extension SheetManager: BatchFilenameRenameRouting {
    /// Открывает route без Flow, callback-ов и mutable состояния feature в SheetManager.
    func presentBatchFilenameRename(
        pendingAction: PendingBulkTrackAction,
        tracks: [BatchFilenameRenameTrackSeed]
    ) {
        present(
            .batchFilenameRename(
                BatchFilenameRenameSheetData(
                    id: UUID(),
                    pendingAction: pendingAction,
                    tracks: tracks
                )
            )
        )
    }

}

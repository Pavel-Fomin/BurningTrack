//
//  BatchFilenameRenameActionHandler.swift
//  TrackList
//
//  Выполняет операции feature массового переименования вне SwiftUI View.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Узкий посредник между ViewModel и domain/write-зависимостями Batch Filename Rename.
@MainActor
final class BatchFilenameRenameActionHandler {
    /// Загружает runtime metadata route без знания UI feature.
    private let metadataLoader: any BatchFilenameRenameMetadataLoading
    /// Содержит чистые правила проверки и построения batch-плана.
    private let planBuilder: BatchFilenameRenamePlanBuilder
    /// Выполняет существующий batch writer вместе с library update pipeline.
    private let commandExecutor: any BatchFilenameRenameCommandExecuting
    /// Проверяет занятость файла плеером перед физическим rename.
    private let fileBusyChecker: any TrackFileBusyChecking
    /// Маршрутизирует закрытие sheet через общий lifecycle.
    private let router: any BatchFilenameRenameRouting

    init(
        metadataLoader: any BatchFilenameRenameMetadataLoading,
        planBuilder: BatchFilenameRenamePlanBuilder,
        commandExecutor: any BatchFilenameRenameCommandExecuting,
        fileBusyChecker: any TrackFileBusyChecking,
        router: any BatchFilenameRenameRouting
    ) {
        self.metadataLoader = metadataLoader
        self.planBuilder = planBuilder
        self.commandExecutor = commandExecutor
        self.fileBusyChecker = fileBusyChecker
        self.router = router
    }

    /// Подготавливает immutable track-данные и передаёт progress во ViewModel.
    func loadTracks(
        from seeds: [BatchFilenameRenameTrackSeed],
        progress: @escaping @MainActor (Int, Int) -> Void
    ) async -> [BatchFilenameRenameTrack] {
        await metadataLoader.loadTracks(from: seeds, progress: progress)
    }

    /// Выполняет первичную validation metadata без выбора стратегии.
    func makeMetadataValidationItems(
        for tracks: [BatchFilenameRenameTrack]
    ) -> [BatchFilenameRenameItem] {
        planBuilder.makeMetadataValidationItems(for: tracks)
    }

    /// Строит preview новой стратегии с сохранением применённых статусов.
    func makePlan(
        strategy: FilenameRenameStrategy,
        tracks: [BatchFilenameRenameTrack],
        preserving items: [BatchFilenameRenameItem]
    ) -> [BatchFilenameRenameItem] {
        planBuilder.makePlan(strategy: strategy, tracks: tracks, preserving: items)
    }

    /// Выделяет ready-строки в команды существующего writer.
    func makeCommands(
        from items: [BatchFilenameRenameItem]
    ) -> [BatchFilenameRenameCommand] {
        planBuilder.makeCommands(from: items)
    }

    /// Запускает физическое переименование, не дублируя library update pipeline.
    func apply(
        commands: [BatchFilenameRenameCommand],
        progress: (@MainActor (_ processed: Int, _ total: Int) -> Void)?
    ) async -> BatchFilenameRenameResult {
        await commandExecutor.renameTrackFilesBatch(
            commands,
            using: fileBusyChecker,
            progress: progress
        )
    }

    /// Сопоставляет writer-результат существующим строкам draft.
    func apply(
        result: BatchFilenameRenameResult,
        to items: [BatchFilenameRenameItem]
    ) -> [BatchFilenameRenameItem] {
        planBuilder.applying(result, to: items)
    }

    /// Закрывает feature через typed routing contract.
    func close(routeID: UUID) {
        router.dismissBatchFilenameRename(routeID)
    }
}

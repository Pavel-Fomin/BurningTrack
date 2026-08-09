//
//  BatchFilenameRenameFeatureFactory.swift
//  TrackList
//
//  Собирает production-граф Batch Filename Rename.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Собирает feature-local MVVM граф из явных production-зависимостей Composition Root.
@MainActor
struct BatchFilenameRenameFeatureFactory {
    /// Загружает runtime metadata выбранных route строк.
    private let metadataLoader: any BatchFilenameRenameMetadataLoading
    /// Выполняет чистые правила подготовки массового rename-плана.
    private let planBuilder: BatchFilenameRenamePlanBuilder
    /// Запускает существующий batch writer и library update pipeline.
    private let commandExecutor: any BatchFilenameRenameCommandExecuting
    /// Проверяет занятость файла текущим playback.
    private let fileBusyChecker: any TrackFileBusyChecking
    /// Открывает и закрывает immutable sheet route.
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

    /// Создаёт один стабильный StateObject-контейнер по immutable route payload.
    func makeView(data: BatchFilenameRenameSheetData) -> BatchFilenameRenameContainer {
        let presenter = BatchFilenameRenamePresenter()
        let actionHandler = BatchFilenameRenameActionHandler(
            metadataLoader: metadataLoader,
            planBuilder: planBuilder,
            commandExecutor: commandExecutor,
            fileBusyChecker: fileBusyChecker,
            router: router
        )
        let viewModel = BatchFilenameRenameViewModel(
            sheetData: data,
            presenter: presenter,
            actionHandler: actionHandler
        )
        return BatchFilenameRenameContainer(viewModel: viewModel)
    }
}

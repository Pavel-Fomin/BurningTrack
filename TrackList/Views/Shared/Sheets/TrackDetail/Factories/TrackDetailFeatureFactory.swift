//
//  TrackDetailFeatureFactory.swift
//  TrackList
//
//  Собирает production-граф feature Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Собирает Track Detail из узких контрактов, не раскрывая зависимости SwiftUI View.
@MainActor
struct TrackDetailFeatureFactory {
    /// Предоставляет уже подготовленный runtime snapshot.
    private let snapshotProvider: any TrackDetailSnapshotProviding
    /// Подготавливает snapshot при отсутствии runtime-кэша.
    private let snapshotBuilder: any TrackDetailSnapshotBuilding
    /// Резолвит URL локального файла для presentation пути.
    private let fileURLResolver: any TrackDetailFileURLResolving
    /// Выполняет существующую команду записи метаданных.
    private let commandExecutor: any TrackDetailCommandExecuting
    /// Проверяет занятость файла плеером.
    private let fileBusyChecker: any TrackFileBusyChecking
    /// Освобождает файл после подтверждения пользователя.
    private let playbackFileReleaser: any CurrentPlaybackFileReleasing
    /// Показывает общий feedback приложения.
    private let toastPresenter: any ToastPresenting
    /// Закрывает sheet через существующий lifecycle.
    private let router: any TrackDetailRouting
    /// Передаёт существующие события обновления runtime-данных.
    private let eventProvider: any TrackDetailEventProviding

    init(
        snapshotProvider: any TrackDetailSnapshotProviding,
        snapshotBuilder: any TrackDetailSnapshotBuilding,
        fileURLResolver: any TrackDetailFileURLResolving,
        commandExecutor: any TrackDetailCommandExecuting,
        fileBusyChecker: any TrackFileBusyChecking,
        playbackFileReleaser: any CurrentPlaybackFileReleasing,
        toastPresenter: any ToastPresenting,
        router: any TrackDetailRouting,
        eventProvider: any TrackDetailEventProviding
    ) {
        self.snapshotProvider = snapshotProvider
        self.snapshotBuilder = snapshotBuilder
        self.fileURLResolver = fileURLResolver
        self.commandExecutor = commandExecutor
        self.fileBusyChecker = fileBusyChecker
        self.playbackFileReleaser = playbackFileReleaser
        self.toastPresenter = toastPresenter
        self.router = router
        self.eventProvider = eventProvider
    }

    /// Создаёт стабильный корневой контейнер по неизменяемому sheet route payload.
    func makeView(data: TrackDetailSheetData) -> TrackDetailContainer {
        let presenter = TrackDetailPresenter(toastPresenter: toastPresenter)
        let actionHandler = TrackDetailActionHandler(
            snapshotProvider: snapshotProvider,
            snapshotBuilder: snapshotBuilder,
            fileURLResolver: fileURLResolver,
            commandExecutor: commandExecutor,
            fileBusyChecker: fileBusyChecker,
            playbackFileReleaser: playbackFileReleaser,
            presenter: presenter,
            router: router,
            routeID: data.id
        )
        let viewModel = TrackDetailViewModel(
            track: data.track,
            initialMode: data.initialMode,
            presenter: presenter,
            actionHandler: actionHandler,
            eventProvider: eventProvider
        )

        return TrackDetailContainer(viewModel: viewModel)
    }
}

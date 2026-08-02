//
//  TrackListViewModelFactory.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Собирает production ViewModel для detail-flow одного треклиста.
@MainActor
struct TrackListViewModelFactory {

    /// Общий action flow переименования файлов, подготовленный Composition Root.
    private let fileRenamer: any TrackFileRenaming
    /// Менеджер содержимого одного треклиста, подготовленный Composition Root.
    private let trackListManager: any TrackListManaging
    /// Менеджер метаданных треклистов, подготовленный Composition Root.
    private let trackListsManager: any TrackListsManaging
    /// Презентер пользовательских сообщений, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
    /// Исполнитель команд, подготовленный Composition Root.
    private let commandExecutor: any TrackListCommandExecuting
    /// Источник событий изменения detail-flow, подготовленный Composition Root.
    private let eventProvider: any TrackListEventProviding
    /// Настройки presentation-состояния, подготовленные Composition Root.
    private let settingsManager: any SettingsManaging
    /// Общий runtime-кэш snapshot-ов, подготовленный Composition Root.
    private let runtimeSnapshotProvider: any TrackRuntimeSnapshotProviding
    /// Сборщик runtime snapshot-ов, подготовленный Composition Root.
    private let runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    /// SQLite-провайдер статистики, подготовленный Composition Root.
    private let summaryProvider: any TrackCollectionSummaryProviding
    /// Реестр metadata локальных треков, подготовленный Composition Root.
    private let trackRegistry: TrackRegistry
    /// Реактивное playback-состояние, подготовленное Composition Root.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Published-состояние «Избранного», подготовленное Composition Root.
    private let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        fileRenamer: any TrackFileRenaming,
        trackListManager: any TrackListManaging,
        trackListsManager: any TrackListsManaging,
        toastPresenter: any ToastPresenting,
        commandExecutor: any TrackListCommandExecuting,
        eventProvider: any TrackListEventProviding,
        settingsManager: any SettingsManaging,
        runtimeSnapshotProvider: any TrackRuntimeSnapshotProviding,
        runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding,
        summaryProvider: any TrackCollectionSummaryProviding,
        trackRegistry: TrackRegistry,
        playbackStateProvider: any PlaybackStateProviding,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    ) {
        self.fileRenamer = fileRenamer
        self.trackListManager = trackListManager
        self.trackListsManager = trackListsManager
        self.toastPresenter = toastPresenter
        self.commandExecutor = commandExecutor
        self.eventProvider = eventProvider
        self.settingsManager = settingsManager
        self.runtimeSnapshotProvider = runtimeSnapshotProvider
        self.runtimeSnapshotBuilder = runtimeSnapshotBuilder
        self.summaryProvider = summaryProvider
        self.trackRegistry = trackRegistry
        self.playbackStateProvider = playbackStateProvider
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
    }

    /// Создаёт production ViewModel для detail-flow одного треклиста.
    func make(trackList: TrackList) -> TrackListViewModel {
        TrackListViewModel(
            trackList: trackList,
            fileRenamer: fileRenamer,
            trackListManager: trackListManager,
            trackListsManager: trackListsManager,
            toastPresenter: toastPresenter,
            commandExecutor: commandExecutor,
            eventProvider: eventProvider,
            settingsManager: settingsManager,
            playbackStateProvider: playbackStateProvider,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            runtimeSnapshotProvider: runtimeSnapshotProvider,
            runtimeSnapshotBuilder: runtimeSnapshotBuilder,
            summaryProvider: summaryProvider,
            trackRegistry: trackRegistry
        )
    }
}

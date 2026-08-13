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

    /// Узкое чтение согласованного detail-снимка одного треклиста.
    private let detailLoader: any TrackListDetailLoading
    /// Презентер пользовательских сообщений, подготовленный Composition Root.
    private let toastPresenter: any ToastPresenting
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
    /// Узкое чтение metadata локальных треков для prepared navigation targets.
    private let collectionMetadataLoader: any TrackCollectionMetadataLoading
    /// Реактивное playback-состояние, подготовленное Composition Root.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Published-состояние «Избранного», подготовленное Composition Root.
    private let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding

    /// Получает готовые production-зависимости и не разрешает singleton самостоятельно.
    init(
        detailLoader: any TrackListDetailLoading,
        toastPresenter: any ToastPresenting,
        eventProvider: any TrackListEventProviding,
        settingsManager: any SettingsManaging,
        runtimeSnapshotProvider: any TrackRuntimeSnapshotProviding,
        runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding,
        summaryProvider: any TrackCollectionSummaryProviding,
        collectionMetadataLoader: any TrackCollectionMetadataLoading,
        playbackStateProvider: any PlaybackStateProviding,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    ) {
        self.detailLoader = detailLoader
        self.toastPresenter = toastPresenter
        self.eventProvider = eventProvider
        self.settingsManager = settingsManager
        self.runtimeSnapshotProvider = runtimeSnapshotProvider
        self.runtimeSnapshotBuilder = runtimeSnapshotBuilder
        self.summaryProvider = summaryProvider
        self.collectionMetadataLoader = collectionMetadataLoader
        self.playbackStateProvider = playbackStateProvider
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
    }

    /// Создаёт production ViewModel для detail-flow одного треклиста.
    func make(trackListId: UUID) -> TrackListViewModel {
        TrackListViewModel(
            trackListId: trackListId,
            detailLoader: detailLoader,
            toastPresenter: toastPresenter,
            eventProvider: eventProvider,
            settingsManager: settingsManager,
            playbackStateProvider: playbackStateProvider,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            runtimeSnapshotProvider: runtimeSnapshotProvider,
            runtimeSnapshotBuilder: runtimeSnapshotBuilder,
            summaryProvider: summaryProvider,
            collectionMetadataLoader: collectionMetadataLoader
        )
    }
}

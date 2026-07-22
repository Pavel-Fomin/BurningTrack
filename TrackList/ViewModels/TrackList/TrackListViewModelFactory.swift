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

    /// Создаёт production ViewModel для detail-flow одного треклиста.
    func make(
        trackList: TrackList,
        playerManager: PlayerManager,
        playbackStateProvider: any PlaybackStateProviding
    ) -> TrackListViewModel {
        TrackListViewModel(
            trackList: trackList,
            fileRenamer: TrackFileRenameActionHandler(
                playerManager: playerManager,
                sheetManager: SheetManager.shared,
                commandExecutor: AppCommandExecutor.shared,
                toastManager: ToastManager.shared,
                proposalBuilder: FileRenameProposalBuilder()
            ),
            trackListManager: TrackListManager.shared,
            trackListsManager: TrackListsManager.shared,
            toastPresenter: ToastManager.shared,
            commandExecutor: AppCommandExecutor.shared,
            eventProvider: NotificationTrackListEventProvider(),
            settingsManager: AppSettingsManager.shared,
            playbackStateProvider: playbackStateProvider,
            runtimeSnapshotProvider: TrackRuntimeStore.shared,
            runtimeSnapshotBuilder: TrackRuntimeSnapshotBuilder.shared,
            summaryProvider: makeSummaryProvider()
        )
    }

    /// Собирает общий SQLite-компонент статистики для detail-экрана треклиста.
    private func makeSummaryProvider() -> any TrackCollectionSummaryProviding {
        do {
            return try SQLiteTrackCollectionSummaryProvider()
        } catch {
            preconditionFailure("Не удалось создать SQLite-провайдер статистики: \(error)")
        }
    }
}

//
//  PlayerFlowActionHandler.swift
//  TrackList
//
//  Единая точка обработки пользовательских действий экрана плеера.
//
//  Created by Codex on 13.06.2026.
//

import Foundation

/// Маршрутизирует пользовательские действия экрана плеера
/// между специализированными обработчиками Player Flow.
///
/// Не хранит состояние экрана.
/// Не выполняет сценарии напрямую.
/// Не обращается к UI и infrastructure singleton-слоям.
final class PlayerFlowActionHandler {

    // MARK: - Dependencies

    /// Обработчик playback-действий.
    private let playbackActionHandler: PlayerPlaybackActionHandler

    /// Обработчик действий над очередью.
    private let queueActionHandler: PlayerQueueActionHandler

    /// Обработчик presentation-действий.
    private let presentationActionHandler: PlayerPresentationActionHandler

    /// Обработчик экспорта очереди плеера.
    private let exportActionHandler: PlayerExportActionHandler

    /// Обработчик rename-действий плеера.
    private let renameActionHandler: PlayerRenameActionHandler

    // MARK: - Инициализация

    @MainActor
    init(
        playbackActionHandler: PlayerPlaybackActionHandler,
        queueActionHandler: PlayerQueueActionHandler,
        presentationActionHandler: PlayerPresentationActionHandler,
        exportActionHandler: PlayerExportActionHandler,
        renameActionHandler: PlayerRenameActionHandler
    ) {
        self.playbackActionHandler = playbackActionHandler
        self.queueActionHandler = queueActionHandler
        self.presentationActionHandler = presentationActionHandler
        self.exportActionHandler = exportActionHandler
        self.renameActionHandler = renameActionHandler
    }

    // MARK: - Actions

    @MainActor
    func handle(_ action: PlayerScreenAction) {
        switch action {
        case .playPause(let queueItemId):
            playbackActionHandler.playPause(queueItemId: queueItemId)
        case .moveTracks(let from, let to):
            queueActionHandler.moveTracks(from: from, to: to)
        case .deleteTrack(let queueItemId):
            queueActionHandler.deleteTrack(queueItemId: queueItemId)
        case .showInLibrary(let queueItemId):
            presentationActionHandler.showInLibrary(queueItemId: queueItemId)
        case .moveToFolder(let queueItemId):
            presentationActionHandler.moveToFolder(queueItemId: queueItemId)
        case .addToTrackList(let queueItemId):
            presentationActionHandler.addToTrackList(queueItemId: queueItemId)
        case .goToArtist(let queueItemId):
            presentationActionHandler.goToArtist(queueItemId: queueItemId)
        case .goToAlbum(let queueItemId):
            presentationActionHandler.goToAlbum(queueItemId: queueItemId)
        case .copyTrack(let queueItemId):
            presentationActionHandler.copyTrack(queueItemId: queueItemId)
        case .editTags(let queueItemId):
            presentationActionHandler.editTags(queueItemId: queueItemId)
        case .renameTrack(
            let queueItemId,
            let strategy
        ):
            renameActionHandler.renameTrack(
                queueItemId: queueItemId,
                strategy: strategy
            )
        case .artworkTap(let queueItemId):
            presentationActionHandler.artworkTap(queueItemId: queueItemId)
        case .requestSnapshot(let trackId):
            playbackActionHandler.requestSnapshot(trackId: trackId)
        case .saveTrackList:
            presentationActionHandler.saveTrackList()
        case .exportTrackList:
            exportActionHandler.exportTrackList()
        case .clearTrackList:
            queueActionHandler.clearTrackList()
        }
    }

}

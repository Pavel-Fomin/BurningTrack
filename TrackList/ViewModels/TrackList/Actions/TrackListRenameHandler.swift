//
//  TrackListRenameHandler.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает rename-flow файла трека внутри одного треклиста.
/// Не выполняет переименование сам, а передаёт готовый request общему файловому handler-у.
@MainActor
final class TrackListRenameHandler {

    /// Читает подготовленный detail snapshot и runtime metadata строки.
    private let reader: any TrackListReading
    /// Запускает общий файловый rename-flow.
    private let fileRenamer: any TrackFileRenaming
    /// Показывает ограничение файловых операций для iTunes-строки.
    private let toastPresenter: any ToastPresenting

    /// Создаёт обработчик rename-flow файла трека.
    init(
        reader: any TrackListReading,
        fileRenamer: any TrackFileRenaming,
        toastPresenter: any ToastPresenting
    ) {
        self.reader = reader
        self.fileRenamer = fileRenamer
        self.toastPresenter = toastPresenter
    }

    /// Запускает переименование файла трека из строки треклиста.
    func renameFile(
        rowId: UUID,
        strategy: FileRenameStrategy
    ) {
        guard let track = reader.track(forRowId: rowId) else {
            return
        }
        guard track.isPurchasedITunesRuntimeTrack == false else {
            toastPresenter.handle(
                .operationFailed(
                    message: PlayerPresentationText.purchasedITunesActionUnavailableMessage
                )
            )
            return
        }

        let snapshot = reader.runtimeSnapshot(forTrackId: track.trackId)
        fileRenamer.handle(
            TrackFileRenameRequest(
                trackId: track.trackId,
                rowId: track.id,
                currentFileName: snapshot?.fileName ?? track.fileName,
                artist: snapshot?.artist,
                title: snapshot?.title,
                strategy: strategy
            )
        )
    }
}

//
//  TrackListFlowActionHandler.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает действия detail-flow одного треклиста.
/// На этом уровне View уже не выполняет бизнес-логику сама.
@MainActor
final class TrackListFlowActionHandler {

    /// Обработчик presentation-действий одного треклиста.
    private let presentationHandler: TrackListPresentationHandler

    /// Обработчик playback-действий одного треклиста.
    private let playbackHandler: TrackListPlaybackHandler

    /// Обработчик изменений одного треклиста.
    private let mutationHandler: TrackListMutationHandler

    /// Обработчик export-flow одного треклиста.
    private let exportHandler: TrackListExportHandler

    /// Обработчик rename-flow файла трека.
    private let renameHandler: TrackListRenameHandler

    /// Создаёт обработчик действий detail-flow одного треклиста.
    init(
        reader: any TrackListReading,
        playbackManager: any TrackListPlaybackManaging,
        mutator: any TrackListMutating,
        renamer: any TrackListRenaming,
        presenter: any TrackListPresenting,
        exportProgressViewModel: ExportProgressViewModel,
        viewControllerProvider: any ViewControllerProviding,
        toastPresenter: any ToastPresenting
    ) {
        self.presentationHandler = TrackListPresentationHandler(
            reader: reader,
            presenter: presenter,
            toastPresenter: toastPresenter,
            collectionNavigationHandler: .shared
        )
        self.playbackHandler = TrackListPlaybackHandler(
            reader: reader,
            playbackManager: playbackManager
        )
        self.mutationHandler = TrackListMutationHandler(mutator: mutator)
        self.exportHandler = TrackListExportHandler(
            reader: reader,
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: viewControllerProvider,
            toastPresenter: toastPresenter
        )
        self.renameHandler = TrackListRenameHandler(renamer: renamer)
    }

    /// Выполняет действие detail-flow одного треклиста.
    func handle(_ action: TrackListAction) {
        switch action {

        case .addTrack:
            presentationHandler.presentAddTrack()

        case .export:
            exportHandler.exportTracks()

        case .renameTrackList:
            presentationHandler.presentRenameTrackList()

        case .rowTapped(let rowId):
            playbackHandler.handleRowTap(rowId: rowId)

        case .deleteTrack(let rowId):
            mutationHandler.deleteTrack(rowId: rowId)

        case .copyTrack(let rowId):
            presentationHandler.copyTrack(rowId: rowId)

        case .addToPlayer(let rowId):
            presentationHandler.addToPlayer(rowId: rowId)

        case .moveTrack(let source, let destination):
            mutationHandler.moveTrack(from: source, to: destination)

        case .renameFile(let rowId, let strategy):
            renameHandler.renameFile(rowId: rowId, strategy: strategy)

        case .artworkTapped(let rowId):
            presentationHandler.presentTrackDetail(rowId: rowId)

        case .editTags(let rowId):
            presentationHandler.presentTrackTagsEditor(rowId: rowId)

        case .showInLibrary(let rowId):
            presentationHandler.showInLibrary(rowId: rowId)

        case .moveToFolder(let rowId):
            presentationHandler.moveToFolder(rowId: rowId)

        case .goToArtist(let rowId):
            presentationHandler.goToArtist(rowId: rowId)

        case .goToAlbum(let rowId):
            presentationHandler.goToAlbum(rowId: rowId)
        }
    }
}

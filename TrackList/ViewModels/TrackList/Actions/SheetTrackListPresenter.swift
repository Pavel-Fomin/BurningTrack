//
//  SheetTrackListPresenter.swift
//  TrackList
//
//  Адаптирует единый sheet-router и координатор к presentation-границе треклиста.
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Production-презентер detail-flow одного треклиста.
/// Адаптирует SheetManager и SheetActionCoordinator к TrackListPresenting.
@MainActor
final class SheetTrackListPresenter: TrackListPresenting {
    private let sheetManager: SheetManager
    private let sheetActionCoordinator: SheetActionCoordinator

    init(
        sheetManager: SheetManager,
        sheetActionCoordinator: SheetActionCoordinator
    ) {
        self.sheetManager = sheetManager
        self.sheetActionCoordinator = sheetActionCoordinator
    }

    func presentAddTrack(to trackListId: UUID) {
        sheetManager.presentNewTrackListSelectionForAppend(
            trackListId: trackListId
        )
    }

    func presentRenameTrackList(
        trackListId: UUID,
        currentName: String
    ) {
        sheetManager.presentRenameTrackList(
            trackListId: trackListId,
            currentName: currentName
        )
    }

    func presentTrackDetail(_ track: Track) {
        sheetManager.presentTrackDetail(track)
    }

    func presentCopyPurchasedITunesTrack(_ track: PurchasedITunesPlayableTrack) {
        sheetManager.presentCopyPurchasedITunesToFolder(for: track)
    }

    func presentTrackTagsEditor(_ track: Track) {
        sheetManager.presentTrackDetailForEditing(track)
    }

    func showInLibrary(_ track: Track) {
        sheetActionCoordinator.showInLibrary(track)
    }

    func moveToFolder(_ track: Track) {
        sheetManager.presentMoveToFolder(for: track)
    }
}

//
//  SheetTrackListPresenter.swift
//  TrackList
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
        sheetManager.present(.trackDetail(track))
    }

    func showInLibrary(_ track: Track) {
        sheetActionCoordinator.handle(
            action: .showInLibrary,
            track: track,
            context: .tracklist
        )
    }

    func moveToFolder(_ track: Track) {
        sheetActionCoordinator.handle(
            action: .moveToFolder,
            track: track,
            context: .tracklist
        )
    }
}

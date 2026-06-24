//
//  TrackListFlowActionHandlerFactory.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Собирает production action handler для detail-flow одного треклиста.
@MainActor
struct TrackListFlowActionHandlerFactory {

    /// Создаёт production action handler для detail-flow одного треклиста.
    func make(
        reader: any TrackListReading,
        playbackManager: any TrackListPlaybackManaging,
        mutator: any TrackListMutating,
        renamer: any TrackListRenaming,
        requestPioneerDestinationPicker: @escaping @MainActor () -> Void
    ) -> TrackListFlowActionHandler {
        TrackListFlowActionHandler(
            reader: reader,
            playbackManager: playbackManager,
            mutator: mutator,
            renamer: renamer,
            presenter: SheetTrackListPresenter(
                sheetManager: SheetManager.shared,
                sheetActionCoordinator: SheetActionCoordinator.shared
            ),
            exporter: ExportManager.shared,
            pioneerExportService: PioneerDeckExportService(),
            viewControllerProvider: ApplicationViewControllerProvider(),
            toastPresenter: ToastManager.shared,
            requestPioneerDestinationPicker: requestPioneerDestinationPicker
        )
    }
}

//
//  LibraryTracksContainer.swift
//  TrackList
//
//  Удерживает graph экранной возможности Library Tracks.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import SwiftUI

/// Создаёт graph folder-экрана через StateObject один раз для identity destination.
/// Благодаря отложенному initializer StateObject factory не выполняет production composition
/// при каждом пересчёте LibraryFolderView.body.
struct LibraryTracksContainer: View {
    let folder: LibraryFolder
    let summary: TrackCollectionSummary?
    let subfolders: [LibraryFolder]
    let revealRequest: LibraryRevealRequest?
    let onSubfolderTap: (LibraryFolder) -> Void
    let onExportTracks: ([LibraryTrack]) -> Void
    let onRevealHandled: (UUID) -> Void
    @Binding var selectionActionBarConfig: SelectionActionBarConfig?
    @Binding var selectionActionSender: (any LibraryTracksActionSending)?

    @StateObject private var screenStore: LibraryTracksScreenStore

    init(
        factory: LibraryTracksScreenFactory,
        folder: LibraryFolder,
        summary: TrackCollectionSummary?,
        subfolders: [LibraryFolder],
        revealRequest: LibraryRevealRequest?,
        onSubfolderTap: @escaping (LibraryFolder) -> Void,
        onExportTracks: @escaping ([LibraryTrack]) -> Void,
        onRevealHandled: @escaping (UUID) -> Void,
        selectionActionBarConfig: Binding<SelectionActionBarConfig?>,
        selectionActionSender: Binding<(any LibraryTracksActionSending)?>
    ) {
        self.folder = folder
        self.summary = summary
        self.subfolders = subfolders
        self.revealRequest = revealRequest
        self.onSubfolderTap = onSubfolderTap
        self.onExportTracks = onExportTracks
        self.onRevealHandled = onRevealHandled
        self._selectionActionBarConfig = selectionActionBarConfig
        self._selectionActionSender = selectionActionSender
        self._screenStore = StateObject(
            wrappedValue: factory.makeScreenStore(
                folder: folder,
                revealRequest: revealRequest
            )
        )
    }

    var body: some View {
        LibraryTracksView(
            folder: folder,
            summary: summary,
            subfolders: subfolders,
            onSubfolderTap: onSubfolderTap,
            onExportTracks: onExportTracks,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled,
            favoriteTrackIdsProvider: screenStore.favoriteTrackIdsProvider,
            tracksViewModel: screenStore.tracksViewModel,
            cloudAvailabilityController: screenStore.cloudAvailabilityController,
            settingsManager: screenStore.settingsManager,
            playbackStateController: screenStore.playbackStateController,
            revealCoordinator: screenStore.revealCoordinator,
            presentationHandler: screenStore.presentationHandler,
            commandHandler: screenStore.commandHandler,
            selectionActionBarConfig: $selectionActionBarConfig,
            selectionActionSender: $selectionActionSender
        )
    }
}

//
//  NewTrackListSelectionFolderActionHandler.swift
//  TrackList
//
//  Маршрутизирует typed действия folder selection в Library Tracks.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Адаптирует узкие намерения selection folder к каноническому ingress Library Tracks.
@MainActor
final class NewTrackListSelectionFolderActionHandler {
    /// Возможность Library Tracks передаётся явно из feature factory.
    private let libraryTracks: any NewTrackListSelectionFolderLibraryTracksHandling

    init(libraryTracks: any NewTrackListSelectionFolderLibraryTracksHandling) {
        self.libraryTracks = libraryTracks
    }

    /// Передаёт lifecycle и runtime intent соответствующему владельцу Library Tracks.
    func handle(_ action: NewTrackListSelectionFolderAction) {
        switch action {
        case .screenAppeared:
            libraryTracks.send(.screenAppeared)
        case .snapshotRequested(let trackID):
            libraryTracks.requestSnapshotIfNeeded(for: trackID)
        }
    }
}

/// Узкая capability скрывает raw LibraryTracksViewModel от selection-folder View.
@MainActor
protocol NewTrackListSelectionFolderLibraryTracksHandling: AnyObject {
    func send(_ action: LibraryTracksAction)
    func requestSnapshotIfNeeded(for trackID: UUID)
}

extension LibraryTracksViewModel: NewTrackListSelectionFolderLibraryTracksHandling {}

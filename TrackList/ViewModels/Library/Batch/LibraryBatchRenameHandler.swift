//
//  LibraryBatchRenameHandler.swift
//  TrackList
//
//  Маршрутизирует массовое переименование файлов фонотеки.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Тонкий адаптер Library Tracks без metadata, плана, apply и mutable feature-state.
@MainActor
final class LibraryBatchRenameHandler {
    /// Открывает immutable route через общий lifecycle sheet-ов.
    private let router: any BatchFilenameRenameRouting

    init(router: any BatchFilenameRenameRouting) {
        self.router = router
    }

    /// Собирает snapshot выбранных строк и сразу передаёт его в feature-local sheet.
    func startRename(
        with pendingAction: PendingBulkTrackAction,
        tracks: [LibraryTrack]
    ) {
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.trackId, $0) })
        let seeds: [BatchFilenameRenameTrackSeed] = pendingAction.trackIDs.compactMap { trackID in
            guard let track = tracksByID[trackID] else { return nil }

            return BatchFilenameRenameTrackSeed(
                trackId: track.trackId,
                folderPath: track.fileURL.deletingLastPathComponent().standardizedFileURL.path,
                currentFileName: track.fileURL.lastPathComponent,
                artist: track.artist,
                title: track.title
            )
        }
        guard !seeds.isEmpty else { return }

        router.presentBatchFilenameRename(
            pendingAction: PendingBulkTrackAction(
                action: pendingAction.action,
                trackIDs: seeds.map(\.trackId)
            ),
            tracks: seeds
        )
    }
}

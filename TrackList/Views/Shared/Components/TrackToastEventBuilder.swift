//
//  TrackToastEventBuilder.swift
//  TrackList
//
//  Builder для формирования Toast-событий, связанных с треками.
//
//  Роль:
//  - подготавливает данные трека (title, artist, artwork);
//  - использует runtime snapshot, если доступен;
//  - при необходимости строит snapshot;
//  - подготавливает обложку для Toast;
//  - не показывает Toast самостоятельно;
//  - не содержит бизнес-логики.
//
//  Created by Pavel Fomin on 05.05.2026.
//

import Foundation

enum TrackToastEventBuilder {
    /// Создаёт track-style Toast для добавления одного трека в треклист.
    static func trackAddedToTrackList(
        track: LibraryTrack,
        trackListName: String
    ) async -> ToastEvent {
        let snapshot: TrackRuntimeSnapshot?

        if let storedSnapshot = await TrackRuntimeStore.shared.snapshot(forTrackId: track.trackId) {
            snapshot = storedSnapshot
        } else {
            snapshot = try? await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: track.trackId)
        }

        let artwork = ArtworkRequest(
            trackId: track.trackId,
            snapshot: snapshot,
            purpose: .toast
        )

        return .trackAddedToTrackList(
            title: snapshot?.title ?? track.title ?? track.fileName,
            artist: snapshot?.artist ?? track.artist ?? "",
            artwork: artwork,
            trackListName: trackListName
        )
    }
}

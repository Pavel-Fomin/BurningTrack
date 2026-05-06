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

import SwiftUI

enum TrackToastEventBuilder {
    /// Создаёт track-style Toast для добавления одного трека в треклист.
    static func trackAddedToTrackList(
        track: LibraryTrack,
        trackListName: String
    ) async -> ToastEvent {
        let snapshot: TrackRuntimeSnapshot?

        if let storedSnapshot = TrackRuntimeStore.shared.snapshot(forTrackId: track.id) {
            snapshot = storedSnapshot
        } else {
            snapshot = await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: track.id)
        }

        let artwork: Image?
        if let data = snapshot?.artworkData,
           let uiImage = ArtworkProvider.shared.image(
               trackId: track.id,
               artworkData: data,
               purpose: .toast
           ) {
            artwork = Image(uiImage: uiImage)
        } else {
            artwork = nil
        }

        return .trackAddedToTrackList(
            title: snapshot?.title ?? track.title ?? track.fileName,
            artist: snapshot?.artist ?? track.artist ?? "",
            artwork: artwork,
            trackListName: trackListName
        )
    }
}

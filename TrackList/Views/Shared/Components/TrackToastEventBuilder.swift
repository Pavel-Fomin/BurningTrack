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
        await trackAddedToTrackList(
            trackId: track.trackId,
            fallbackFileName: track.fileName,
            fallbackTitle: track.title,
            fallbackArtist: track.artist,
            trackListName: trackListName
        )
    }

    /// Создаёт track-style Toast для добавления трека по предметному результату команды.
    static func trackAddedToTrackList(
        trackId: UUID,
        fallbackFileName: String,
        fallbackTitle: String? = nil,
        fallbackArtist: String? = nil,
        trackListName: String
    ) async -> ToastEvent {
        let snapshot = await snapshot(for: trackId)

        return .trackAddedToTrackList(
            title: snapshot?.title ?? fallbackTitle ?? fallbackFileName,
            artist: snapshot?.artist ?? fallbackArtist ?? "",
            artwork: artwork(for: trackId, snapshot: snapshot),
            trackListName: trackListName
        )
    }

    /// Создаёт track-style Toast для удаления трека из треклиста.
    static func trackRemovedFromTrackList(
        trackId: UUID,
        fallbackFileName: String
    ) async -> ToastEvent {
        let snapshot = await snapshot(for: trackId)

        return .trackRemovedFromTrackList(
            title: snapshot?.title ?? fallbackFileName,
            artist: snapshot?.artist ?? "",
            artwork: artwork(for: trackId, snapshot: snapshot)
        )
    }

    /// Создаёт track-style Toast для удаления трека из очереди плеера.
    static func trackRemovedFromPlayer(
        trackId: UUID,
        fallbackFileName: String
    ) async -> ToastEvent {
        let snapshot = await snapshot(for: trackId)

        return .trackRemovedFromPlayer(
            title: snapshot?.title ?? snapshot?.fileName ?? fallbackFileName,
            artist: snapshot?.artist ?? "",
            artwork: artwork(for: trackId, snapshot: snapshot)
        )
    }

    /// Возвращает актуальный snapshot для presentation-данных Toast.
    private static func snapshot(
        for trackId: UUID
    ) async -> TrackRuntimeSnapshot? {
        if let storedSnapshot = await TrackRuntimeStore.shared.snapshot(forTrackId: trackId) {
            return storedSnapshot
        }

        return try? await TrackRuntimeSnapshotBuilder.shared.buildSnapshot(forTrackId: trackId)
    }

    /// Создаёт запрос обложки только при наличии актуального snapshot.
    private static func artwork(
        for trackId: UUID,
        snapshot: TrackRuntimeSnapshot?
    ) -> ArtworkRequest? {
        ArtworkRequest(
            trackId: trackId,
            snapshot: snapshot,
            purpose: .toast
        )
    }
}

//
//  PlayerPresentationText.swift
//  TrackList
//
//  Локализованные подписи presentation-слоя плеера.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует данные плеера в локализованные подписи без изменения playback-логики.
enum PlayerPresentationText {
    static func miniPlayerArtist(for artist: String?) -> String {
        guard let artist = artist?.trimmingCharacters(in: .whitespacesAndNewlines),
              artist.isEmpty == false else {
            return String(localized: "Unknown Artist")
        }

        return artist
    }

    static var trackAddedToPlayerMessage: String {
        String(localized: "toast.player.trackAdded")
    }

    static var trackRemovedFromPlayerMessage: String {
        String(localized: "toast.player.trackRemoved")
    }

    static var playerClearedMessage: String {
        String(localized: "toast.player.cleared")
    }

    static func tracksAddedToPlayerMessage(count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: "toast.player.tracksAdded"),
            count
        )
    }

    static var playlistSavedMessage: String {
        String(localized: "toast.player.saved")
    }

    static var playlistLoadFailedMessage: String {
        String(localized: "toast.player.loadFailed")
    }

    static var playlistSaveFailedMessage: String {
        String(localized: "toast.player.saveFailed")
    }

    static var playbackFailedMessage: String {
        String(localized: "toast.player.playbackFailed")
    }

    static var audioSessionFailedMessage: String {
        String(localized: "toast.player.audioSessionFailed")
    }

    static var trackNotPlayableMessage: String {
        String(localized: "toast.player.trackNotPlayable")
    }

    static var addTrackToPlayerFailedMessage: String {
        String(localized: "toast.player.addTrackFailed")
    }

    static var addTracksToPlayerFailedMessage: String {
        String(localized: "toast.player.addTracksFailed")
    }

    static var addPurchasedITunesTrackToPlayerFailedMessage: String {
        String(localized: "toast.player.addPurchasedITunesTrackFailed")
    }

    static var removeTrackFromPlayerFailedMessage: String {
        String(localized: "toast.player.removeTrackFailed")
    }

    static var purchasedITunesActionUnavailableMessage: String {
        String(localized: "toast.player.purchasedITunesActionUnavailable")
    }
}

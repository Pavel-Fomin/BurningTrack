//
//  PlaybackContext.swift
//  TrackList
//
//  Created by Pavel Fomin on 07.08.2025.
//

import Foundation

enum PlaybackContext {
    case player
    case trackList
    case library
    case unknown
}

extension PlaybackContext {
    static func detect(from context: [any TrackDisplayable]) -> PlaybackContext {
        if context.first is PlayerTrack { return .player }
        if context.first is Track { return .trackList }
        if context.first is LibraryTrack { return .library }
        return .unknown
    }
}

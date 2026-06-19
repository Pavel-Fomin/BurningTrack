//
//  PlayerEventObserving.swift
//  TrackList
//
//  Абстракция источника событий, необходимых PlayerViewModel.
//
//  Created by Pavel Fomin on 19.06.2026.
//

import Foundation

/// Источник событий, необходимых PlayerViewModel.
@MainActor
protocol PlayerEventObserving: AnyObject {

    var onTrackDurationUpdated: ((TimeInterval) -> Void)? { get set }

    var onTrackDidFinish: (() -> Void)? { get set }

    var onTrackDidUpdate: ((TrackUpdateEvent) -> Void)? { get set }

    var onSettingsChanged: (() -> Void)? { get set }
}

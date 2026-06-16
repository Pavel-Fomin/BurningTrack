//
//  NotificationTrackListsEventProvider.swift
//  TrackList
//
//  Провайдер событий списка треклистов через NotificationCenter.
//
//  Created by Pavel Fomin on 16.06.2026.
//

import Foundation
import Combine

@MainActor
final class NotificationTrackListsEventProvider: TrackListsEventProviding {

    /// Событие изменения списка треклистов.
    var trackListsDidChange: AnyPublisher<Void, Never> {
        NotificationCenter.default.publisher(for: .trackListsDidChange)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

//
//  NotificationLibraryTrackEventProvider.swift
//  TrackList
//
//  NotificationCenter-реализация источника событий обновления треков фонотеки.
//
//  Created by Pavel Fomin on 21.06.2026.
//

import Combine
import Foundation

/// Источник событий обновления треков через NotificationCenter.
/// Используется как инфраструктурная реализация LibraryTrackEventProvider.
@MainActor
final class NotificationLibraryTrackEventProvider: LibraryTrackEventProvider {

    /// Позволяет создавать provider как зависимость по умолчанию.
    nonisolated init() {}

    /// Событие обновления одного трека.
    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> {
        NotificationCenter.default.publisher(for: .trackDidUpdate)
            .compactMap { notification in
                notification.object as? TrackUpdateEvent
            }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    /// Событие пакетного обновления треков.
    var trackBatchDidUpdate: AnyPublisher<[TrackUpdateEvent], Never> {
        NotificationCenter.default.publisher(for: .trackBatchDidUpdate)
            .compactMap { notification in
                notification.userInfo?["events"] as? [TrackUpdateEvent]
            }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    /// Событие изменения настроек приложения.
    var appSettingsDidChange: AnyPublisher<Void, Never> {
        NotificationCenter.default.publisher(for: .appSettingsDidChange)
            .map { _ in () }
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    /// Событие изменения данных треклистов.
    var trackListBadgesDidChange: AnyPublisher<Void, Never> {
        let trackListsDidChange = NotificationCenter.default.publisher(for: .trackListsDidChange)
            .map { _ in () }

        let trackListTracksDidChange = NotificationCenter.default.publisher(for: .trackListTracksDidChange)
            .map { _ in () }

        return Publishers.Merge(
            trackListsDidChange,
            trackListTracksDidChange
        )
        .receive(on: RunLoop.main)
        .eraseToAnyPublisher()
    }
}

//
//  NotificationTrackListEventProvider.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Combine
import Foundation

/// Production-провайдер событий detail-flow одного треклиста через NotificationCenter.
final class NotificationTrackListEventProvider: TrackListEventProviding {
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    /// Событие обновления runtime snapshot трека.
    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> {
        notificationCenter.publisher(for: .trackDidUpdate)
            .compactMap { $0.object as? TrackUpdateEvent }
            .eraseToAnyPublisher()
    }

    /// Событие изменения настроек приложения.
    var appSettingsDidChange: AnyPublisher<Void, Never> {
        notificationCenter.publisher(for: .appSettingsDidChange)
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    /// Событие изменения состава треков конкретного треклиста.
    var trackListTracksDidChange: AnyPublisher<UUID, Never> {
        notificationCenter.publisher(for: .trackListTracksDidChange)
            .compactMap { $0.object as? UUID }
            .eraseToAnyPublisher()
    }

    /// Событие завершения синхронизации фонотеки после записи file_size в SQLite.
    var libraryDataDidChange: AnyPublisher<Void, Never> {
        notificationCenter.publisher(for: .libraryDataDidChange)
            .map { _ in () }
            .eraseToAnyPublisher()
    }

    /// Событие изменения списка/метаданных треклистов.
    var trackListsDidChange: AnyPublisher<Void, Never> {
        notificationCenter.publisher(for: .trackListsDidChange)
            .map { _ in () }
            .eraseToAnyPublisher()
    }
}

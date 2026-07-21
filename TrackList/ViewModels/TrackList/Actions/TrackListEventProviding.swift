//
//  TrackListEventProviding.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Combine
import Foundation

/// Предоставляет события, влияющие на detail-flow одного треклиста.
protocol TrackListEventProviding {
    /// Событие обновления runtime snapshot трека.
    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> { get }
    /// Событие изменения настроек приложения.
    var appSettingsDidChange: AnyPublisher<Void, Never> { get }
    /// Событие изменения состава треков конкретного треклиста.
    var trackListTracksDidChange: AnyPublisher<UUID, Never> { get }
    /// Событие завершения синхронизации фонотеки после обновления сохранённых атрибутов файлов.
    var libraryDataDidChange: AnyPublisher<Void, Never> { get }
    /// Событие изменения списка/метаданных треклистов.
    var trackListsDidChange: AnyPublisher<Void, Never> { get }
}

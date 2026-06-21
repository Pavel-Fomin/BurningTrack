//
//  LibraryTrackEventProvider.swift
//  TrackList
//
//  Источник событий обновления треков для фонотеки.
//
//  Created by Pavel Fomin on 21.06.2026.
//

import Combine
import Foundation

/// Источник событий обновления треков для фонотеки.
/// Скрывает конкретный механизм доставки событий от LibraryTracksViewModel.
@MainActor
protocol LibraryTrackEventProvider {

    /// Событие обновления одного трека.
    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> { get }

    /// Событие пакетного обновления треков.
    var trackBatchDidUpdate: AnyPublisher<[TrackUpdateEvent], Never> { get }

    /// Событие изменения настроек приложения,
    /// влияющих на отображение runtime metadata.
    var appSettingsDidChange: AnyPublisher<Void, Never> { get }

    /// Событие изменения данных треклистов,
    /// после которого нужно обновить бейджи принадлежности треков к треклистам.
    var trackListBadgesDidChange: AnyPublisher<Void, Never> { get }
}

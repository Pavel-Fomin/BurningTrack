//
//  TrackSelectableRowState.swift
//  TrackList
//
//  Готовое presentation-состояние строки выбора трека.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Состояние секции строк выбора, подготовленное до передачи в SwiftUI.
struct TrackSelectableSectionState: Identifiable {
    /// Идентификатор секции сохраняет стабильность исходной группировки фонотеки.
    let id: String
    /// Семантический заголовок секции для локализации в View.
    let header: TrackSectionHeader
    /// Готовые строки секции в отображаемом порядке.
    let rows: [TrackSelectableRowState]

    /// Заголовок нужен для всех секций, кроме плоской сортировки.
    var showsHeader: Bool {
        header != .hidden
    }
}

/// Готовое presentation-состояние одной строки выбора трека.
struct TrackSelectableRowState: Identifiable {
    /// Исходный локальный трек нужен для действия выбора без повторного поиска по идентификатору.
    let track: LibraryTrack
    /// Лёгкий запрос обложки для общей асинхронной подсистемы.
    let artworkRequest: ArtworkRequest?
    /// Готовое presentation-состояние бейджа обложки.
    let artworkBadgeState: TrackArtworkBadgeState
    /// Подготовленный заголовок строки.
    let title: String?
    /// Подготовленный исполнитель строки.
    let artist: String?
    /// Подготовленная длительность строки.
    let duration: Double?
    /// Отражает текущий выбор без вычислений во wrapper-строке.
    let isSelected: Bool
    /// Определяет отображение формата файла в правой колонке.
    let showsFileFormat: Bool

    /// Идентификатор строки совпадает с идентификатором трека фонотеки.
    var id: UUID {
        track.id
    }
}

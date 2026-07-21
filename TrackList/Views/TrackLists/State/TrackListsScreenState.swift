//
//  TrackListsScreenState.swift
//  TrackList
//
//  Состояние экрана списка треклистов.
//  View получает готовое состояние и не знает, откуда оно собрано.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

struct TrackListsScreenState {
    /// Строки списка треклистов.
    let rows: [TrackListsRowState]
    /// Идентификатор треклиста, ожидающего подтверждения удаления.
    let pendingDeleteTrackListId: UUID?
    /// Нужно ли показывать диалог удаления.
    let isShowingDeleteConfirmation: Bool
    /// Сортировка, выбранная через меню; nil означает ручной порядок без галочки.
    let selectedSortMode: TrackListsSortMode?
}

struct TrackListsRowState: Identifiable {
    /// Идентификатор треклиста.
    let id: UUID
    /// Модель треклиста для типизированной навигации.
    let trackList: TrackList
    /// Название треклиста.
    let title: String
    /// Дата создания треклиста.
    let createdAt: Date
    /// Количество треков в треклисте.
    let tracksCount: Int
}

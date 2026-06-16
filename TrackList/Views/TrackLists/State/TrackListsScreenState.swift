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
    /// Есть ли треклисты для отображения.
    let isEmpty: Bool
    /// Идентификатор треклиста, ожидающего подтверждения удаления.
    let pendingDeleteTrackListId: UUID?
    /// Нужно ли показывать диалог удаления.
    let isShowingDeleteConfirmation: Bool
}

struct TrackListsRowState: Identifiable {
    /// Идентификатор треклиста.
    let id: UUID
    /// Название треклиста.
    let title: String
    /// Количество треков в треклисте.
    let tracksCountText: String
}

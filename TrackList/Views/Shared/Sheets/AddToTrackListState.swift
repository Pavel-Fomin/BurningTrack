//
//  AddToTrackListState.swift
//  TrackList
//
//  Presentation-состояние feature-flow добавления треков в треклист.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Готовое состояние экрана выбора destination-треклиста.
struct AddToTrackListState: Equatable {
    /// Элементы списка треклистов в отображаемом порядке.
    let items: [AddToTrackListItemState]
    /// Идентификатор выбранного destination-треклиста.
    let selectedTrackListId: UUID?
    /// Доступно ли подтверждение операции.
    let canSubmit: Bool
    /// Загружается ли список доступных треклистов.
    let isLoading: Bool
    /// Выполняется ли команда добавления треков.
    let isSubmitting: Bool
}

/// Presentation-модель одной строки выбора треклиста.
struct AddToTrackListItemState: Identifiable, Equatable {
    /// Идентификатор треклиста назначения.
    let id: UUID
    /// Готовый заголовок строки с учётом типа треклиста.
    let title: String
    /// Выбрана ли строка пользователем.
    let isSelected: Bool
    /// Доступен ли треклист для выбора destination.
    let isAvailable: Bool
}

//
//  BatchTagEditAction.swift
//  TrackList
//
//  Типизированные действия сценария массового редактирования тегов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Описывает пользовательские намерения и lifecycle-события Batch Tag Edit.
enum BatchTagEditAction {
    /// Контейнер появился и должен загрузить metadata выбранных треков.
    case appeared
    /// Пользователь закрыл sheet.
    case closeTapped
    /// SwiftUI сообщил об исчезновении sheet без дополнительной маршрутизации.
    case sheetDisappeared
    /// Пользователь подтвердил сохранение текущего draft.
    case saveTapped
    /// Пользователь изменил отображаемое поле тегов.
    case fieldValueChanged(field: EditableTrackField, value: String)
    /// Пользователь выбрал summary или конкретную artwork-карточку.
    case artworkTargetSelected(BatchTagArtworkActionTarget)
    /// Пользователь запросил удаление artwork для цели.
    case artworkRemoveTapped(target: BatchTagArtworkActionTarget)
    /// Пользователь запросил системный выбор новой artwork.
    case artworkReplaceTapped(target: BatchTagArtworkActionTarget)
    /// PhotosPicker передал байты выбранной artwork.
    case artworkReplacementSelected(
        target: BatchTagArtworkActionTarget,
        data: Data
    )
    /// Пользователь выбрал вариант сжатия artwork.
    case artworkCompressTapped(
        target: BatchTagArtworkActionTarget,
        option: BatchArtworkCompressionOption
    )
}

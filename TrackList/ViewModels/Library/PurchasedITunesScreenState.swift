//
//  PurchasedITunesScreenState.swift
//  TrackList
//
//  Готовое presentation-состояние экрана «Куплено в iTunes».
//
//  Created by Pavel Fomin on 11.08.2026.
//

import Foundation

/// Описывает данные загрузки до их преобразования в отображаемые строки.
enum PurchasedITunesMusicContent: Equatable {
    /// Экран ещё не начал загрузку или ожидает ответ системной медиатеки.
    case idle
    /// Идёт запрос доступа или чтение системной медиатеки.
    case loading
    /// Пользователь или система запретили доступ к медиатеке.
    case denied
    /// Доступ есть, но подходящих локальных треков не найдено.
    case empty
    /// Загружены исходные iTunes-треки в текущем отображаемом порядке.
    case loaded([PurchasedITunesTrack])
}

/// Содержит только подготовленные данные экрана без provider-ов, handler-ов и SwiftUI-зависимостей.
struct PurchasedITunesScreenState: Equatable {

    /// Семантическое состояние основного содержимого экрана.
    enum Content: Equatable {
        case loading
        case denied
        case empty
        case loaded([PurchasedITunesTrackRowState])
    }

    /// Готовое состояние основного содержимого.
    let content: Content
    /// Выбранный и подтверждённый для отображения режим сортировки.
    let sortMode: PurchasedITunesTrackSortMode
    /// Разрешает экспорт только при наличии отображаемых треков.
    let canExport: Bool
    /// Полный playback-контекст в том же порядке, что и строки экрана.
    let tracks: [PurchasedITunesPlayableTrack]
}

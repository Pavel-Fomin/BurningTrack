//
//  TrackMenuAction.swift
//  TrackList
//
//  Каноничные пункты меню трека.
//
//  Created by Codex on 03.07.2026.
//

import Foundation

/// Пункты меню, доступность которых зависит от источника трека и раздела.
enum TrackMenuAction: Hashable {
    /// Открыть карточку "О треке".
    case details
    /// Скопировать iTunes-трек в выбранную папку.
    case copy
    /// Добавить трек в треклист.
    case addToTrackList
    /// Добавить трек в очередь плеера.
    case addToPlayer
    /// Показать локальный файл в фонотеке.
    case showInLibrary
    /// Переместить локальный файл в другую папку.
    case moveToFolder
    /// Редактировать теги локального файла.
    case editTags
    /// Переименовать локальный файл.
    case renameFile
    /// Удалить строку из очереди плеера.
    case deleteFromPlayer
    /// Удалить строку из треклиста.
    case deleteFromTrackList
}

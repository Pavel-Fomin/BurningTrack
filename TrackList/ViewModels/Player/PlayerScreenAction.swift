//
//  PlayerScreenAction.swift
//  TrackList
//
//  Пользовательские действия высокоуровневого экрана плеера.
//
//  Created by Codex on 13.06.2026.
//

import Foundation

/// Пользовательские действия экрана плеера.
///
/// Используется для передачи намерений пользователя
/// из UI в будущий PlayerFlowActionHandler.
///
/// Enum не выполняет действия самостоятельно
/// и не зависит от менеджеров приложения.
enum PlayerScreenAction {

    /// Переключает воспроизведение текущего элемента очереди
    /// или запускает выбранный элемент очереди.
    case playPause(
        queueItemId: UUID
    )

    /// Перемещает выбранные строки в новую позицию плейлиста.
    case moveTracks(
        from: IndexSet,
        to: Int
    )

    /// Удаляет конкретное вхождение трека из очереди плеера.
    case deleteTrack(
        queueItemId: UUID
    )

    /// Открывает расположение трека в фонотеке.
    case showInLibrary(
        queueItemId: UUID
    )

    /// Открывает сценарий перемещения файла трека в другую папку.
    case moveToFolder(
        queueItemId: UUID
    )

    /// Открывает сценарий добавления элемента очереди в треклист.
    case addToTrackList(
        queueItemId: UUID
    )

    /// Открывает редактирование тегов элемента очереди.
    case editTags(
        queueItemId: UUID
    )

    /// Открывает или выполняет сценарий переименования файла трека.
    case renameTrack(
        queueItemId: UUID,
        strategy: FileRenameStrategy
    )

    /// Запрашивает загрузку актуального runtime snapshot трека.
    case requestSnapshot(
        trackId: UUID
    )

    /// Открывает подробную информацию о треке по нажатию на обложку.
    case artworkTap(
        queueItemId: UUID
    )

    /// Открывает сценарий сохранения плейлиста как треклиста.
    case saveTrackList

    /// Запускает экспорт текущего плейлиста.
    case exportTrackList

    /// Очищает текущий плейлист.
    case clearTrackList
}

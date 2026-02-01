//
//  ToastEvent.swift
//  TrackList
//
//  Декларативное описание событий,
//  которые могут быть показаны пользователю в виде тоста.
//
//  ViewModel отправляет ТОЛЬКО ToastEvent.
//  Преобразование в UI-данные происходит в ToastManager.
//
//  Created by Pavel Fomin on 2026.
//

import SwiftUI

enum ToastEvent: Equatable {

    // MARK: - Плеер

    /// Добавить в плеер
    case trackMovedToPlayer(
        title: String,
        artist: String,
        artwork: Image?)
    
    /// Удалить из плеера
    case trackRemovedFromPlayer(
        title: String,
        artist: String,
        artwork: Image?)

    /// Очистить плеер
    case playerCleared

    /// Сохранить треклист
    case trackListSaved(name: String)

    /// Экспорт завершен
    case exportFinished(targetName: String)
    

    // MARK: - Фонотека

    /// Добавлен в плеер
    case trackAddedToPlayer(
        title: String,
        artist: String,
        artwork: Image?)

    /// Добавлен в треклист
    case trackAddedToTrackList(
        title: String,
        artist: String,
        artwork: Image?,
        trackListName: String)

    /// Перемещен
    case trackMovedInLibrary(
        title: String,
        artist: String,
        artwork: Image?,
        folderName: String)
    
    
    // MARK: - Треклист

    /// Удален из треклиста
    case trackRemovedFromTrackList(
        title: String,
        artist: String,
        artwork: Image?)

    /// Треклист переименован
    case trackListRenamed(newName: String)

    // MARK: - Глобальные (на будущее)

    /// Теги обновлены
    case tagsUpdated(
        title: String,
        artist: String,
        artwork: Image?
    )
    
    /// Файл переименован
    case fileRenamed(newName: String)
    
    /// Файл и теги обновлены
    case fileAndTagsUpdated(
        title: String,
        artist: String,
        artwork: Image?
    )
}

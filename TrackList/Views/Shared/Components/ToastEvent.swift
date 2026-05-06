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

    // MARK: - Success

    // MARK: Плеер

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

    case trackListCreated(name: String)

    case trackListCleared(name: String)

    case tracksAddedToTrackList(count: Int, name: String)

    case playlistSaved

    /// Экспорт завершен
    case exportFinished(targetName: String)
    

    // MARK: Фонотека

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

    case folderAdded(name: String)

    case folderRemoved(name: String)
    
    
    // MARK: Треклист

    /// Удален из треклиста
    case trackRemovedFromTrackList(
        title: String,
        artist: String,
        artwork: Image?)

    /// Треклист переименован
    case trackListRenamed(newName: String)

    // MARK: Глобальные

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

    // MARK: - Warning

    case trackUnavailable(title: String)

    case noTracksToExport

    case partialImport(imported: Int, failed: Int)

    case partialExport(exported: Int, failed: Int)

    case libraryAccessNeedsRestore(folderName: String)

    case showInLibraryTargetMissing

    case artworkCouldNotBeLoaded

    // MARK: - Error

    case operationFailed(message: String)

    case playbackFailed(title: String)

    case trackListSaveFailed

    case playlistSaveFailed

    case importFailed

    case exportFailed

    case fileMoveFailed

    case fileRenameFailed

    case tagWriteFailed

    case libraryAccessDenied(folderName: String)

    case presenterUnavailable
}

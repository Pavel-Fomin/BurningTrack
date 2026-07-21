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

    /// Файлы подготовлены к экспорту
    case exportPrepared(targetName: String)
    

    // MARK: Фонотека

    /// Добавлен в плеер
    case trackAddedToPlayer(
        title: String,
        artist: String,
        artwork: Image?)

    /// Несколько треков добавлены в плеер
    case tracksAddedToPlayer(count: Int)

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
        folderName: String?)

    /// Скопирован из iTunes в фонотеку
    case trackCopiedFromITunes(
        title: String,
        artist: String,
        artwork: Image?,
        folderName: String?)

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

    /// Массовое обновление тегов завершено успешно.
    case batchTagsUpdated(count: Int)

    /// Массовое обновление тегов завершено частично.
    case batchTagsPartiallyUpdated(succeeded: Int, failed: Int)

    /// Массовое обновление тегов не выполнено.
    case batchTagsUpdateFailed(failed: Int)
    
    /// Файл переименован
    case fileRenamed(newName: String)
    
    /// Файл и теги обновлены
    case fileAndTagsUpdated(
        title: String,
        artist: String,
        artwork: Image?
    )

    // MARK: - Warning

    case trackUnavailable(title: String?)

    case noTracksToExport

    case partialImport(imported: Int, failed: Int)

    case partialExport(exported: Int, failed: Int)

    case libraryAccessNeedsRestore(folderName: String?)

    case showInLibraryTargetMissing

    case folderNotFound

    case artworkCouldNotBeLoaded

    // MARK: - Error

    case operationFailed(message: String)

    case playbackFailed(title: String?)

    case audioSessionFailed

    case trackListSaveFailed

    case playlistSaveFailed

    case importFailed

    case exportFailed

    case fileMoveFailed

    case fileRenameFailed

    case tagWriteFailed

    case libraryAccessDenied(folderName: String?)

    case presenterUnavailable
}

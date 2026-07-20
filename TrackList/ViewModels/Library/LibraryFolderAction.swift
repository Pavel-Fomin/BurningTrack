//
//  LibraryFolderAction.swift
//  TrackList
//
//  Действия пользователя на экране папки фонотеки.
//  View только отправляет действия, но не выполняет бизнес-логику.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

enum LibraryFolderAction {
    case appeared
    case subfolderTapped(LibraryFolder)
    /// Запускает экспорт видимых треков текущей папки в их отображаемом порядке.
    case exportTracks([LibraryTrack])
}

//
//  AppError.swift
//  TrackList
//
//  Список всех возможных ошибок приложения
//
//  Created by Pavel Fomin on 20.05.2025.
//

import Foundation

enum AppError: Error {
    case fileNotFound
    case fileAccessDenied
    case fileNotPlayable
    case fileAlreadyExists
    case fileMoveFailed
    case fileRenameFailed
    case bookmarkMissing
    case bookmarkStale
    case bookmarkResolveFailed
    case bookmarkCreateFailed
    case libraryFolderAccessDenied
    case libraryFolderUnavailable
    case libraryRestoreFailed
    case librarySyncFailed
    case trackUnavailable
    case trackNotFound
    case trackListNotFound
    case trackListLoadFailed
    case trackListSaveFailed
    case trackListNameInvalid
    case playlistLoadFailed
    case playlistSaveFailed
    case importFailed
    case importPartiallyFailed
    case exportNoTracks
    case exportNoFilesPrepared
    case exportFailed
    case playbackFailed
    case audioSessionFailed
    case metadataReadFailed
    case tagWriteFailed
    case artworkLoadFailed
    case showInLibraryFailed
    case presenterUnavailable
    case unknown
}

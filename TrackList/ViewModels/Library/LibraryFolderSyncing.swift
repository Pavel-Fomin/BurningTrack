//
//  LibraryFolderSyncing.swift
//  TrackList
//
//  Контракт manager-синхронизации папки для экранной догрузки фонотеки.
//
//  Created by Pavel Fomin on 21.08.2026.
//

import Foundation

/// Описывает существующую manager-операцию синхронизации папки без передачи ViewModel root ownership.
@MainActor
protocol LibraryFolderSyncing: AnyObject {
    /// Возвращает подтверждённый sync либо явную причину безопасного пропуска.
    func syncFolderIfNeeded(folderId: UUID) async throws -> LibrarySyncOutcome
}

/// Production-менеджер сохраняет собственную per-root coordination model за узким контрактом.
extension MusicLibraryManager: LibraryFolderSyncing {}

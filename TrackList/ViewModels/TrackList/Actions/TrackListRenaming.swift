//
//  TrackListRenaming.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Запускает rename-flow файла трека внутри одного треклиста.
@MainActor
protocol TrackListRenaming {
    /// Переименовывает файл трека по идентификатору строки.
    func renameTrack(
        rowId: UUID,
        strategy: FileRenameStrategy
    )
}

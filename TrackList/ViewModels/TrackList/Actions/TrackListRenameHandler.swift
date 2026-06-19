//
//  TrackListRenameHandler.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает rename-flow файла трека внутри одного треклиста.
/// Не выполняет переименование сам, а делегирует запуск через TrackListRenaming.
@MainActor
final class TrackListRenameHandler {

    /// Запускает rename-flow строки треклиста.
    private let renamer: any TrackListRenaming

    /// Создаёт обработчик rename-flow файла трека.
    init(renamer: any TrackListRenaming) {
        self.renamer = renamer
    }

    /// Запускает переименование файла трека из строки треклиста.
    func renameFile(
        rowId: UUID,
        strategy: FileRenameStrategy
    ) {
        renamer.renameTrack(
            rowId: rowId,
            strategy: strategy
        )
    }
}

//
//  TrackListCommandExecuting.swift
//  TrackList
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Выполняет команды изменения одного треклиста.
protocol TrackListCommandExecuting {
    /// Удаляет строку трека из треклиста.
    func removeTrackFromTrackList(
        listItemId: UUID,
        trackListId: UUID
    ) async throws
}

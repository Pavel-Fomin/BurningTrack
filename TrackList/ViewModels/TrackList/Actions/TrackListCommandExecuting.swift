//
//  TrackListCommandExecuting.swift
//  TrackList
//
//  Объявляет capability изменения состава одного пользовательского треклиста.
//
//  Created by Pavel Fomin on 18.06.2026.
//

import Foundation

/// Выполняет команды изменения одного треклиста через MainActor-bound application command flow.
@MainActor
protocol TrackListCommandExecuting {
    /// Удаляет строку трека из треклиста.
    func removeTrackFromTrackList(
        listItemId: UUID,
        trackListId: UUID
    ) async throws -> TrackRemovedFromTrackListSuccess
}

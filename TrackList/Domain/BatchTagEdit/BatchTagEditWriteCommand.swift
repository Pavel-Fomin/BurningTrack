//
//  BatchTagEditWriteCommand.swift
//  TrackList
//
//  Команда записи тегов для одного трека.
//
//  Created by Pavel Fomin on 27.05.2026.
//

import Foundation

/// Команда записи тегов для одного трека.
struct BatchTagEditWriteCommand: Identifiable, Equatable {
    /// Идентификатор трека.
    let trackId: UUID
    /// Patch текстовых тегов.
    let patch: TagWritePatch
    /// Действие с обложкой.
    let artworkAction: ArtworkWriteAction
    /// Идентификатор команды.
    var id: UUID {
        trackId
    }
}

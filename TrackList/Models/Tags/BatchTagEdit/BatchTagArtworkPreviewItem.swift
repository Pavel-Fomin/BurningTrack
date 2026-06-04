//
//  BatchTagArtworkPreviewItem.swift
//  TrackList
//
//  Элемент preview обложки в форме массового редактирования тегов.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

/// Элемент preview обложки в форме массового редактирования тегов.
struct BatchTagArtworkPreviewItem: Identifiable, Equatable {
    /// Идентификатор элемента preview.
    let id: UUID
    /// Идентификатор трека.
    let trackId: UUID
    /// Название, которое отображается под обложкой.
    let title: String
    /// Есть ли у трека обложка.
    let hasArtwork: Bool
}

//
//  BatchTagArtworkSizeFormatter.swift
//  TrackList
//
//  Форматирование размера обложки для массового редактирования тегов.
//
//  Created by Pavel Fomin on 11.06.2026.
//

import Foundation

/// Форматирует размер обложки для отображения в BatchTagEdit.
enum BatchTagArtworkSizeFormatter {
    /// Возвращает читаемый размер обложки.
    static func string(from bytes: Int) -> String {
        guard bytes > 0 else {
            return BatchTagEditPresentationText.noArtworkTitle
        }

        return ByteCountFormatter.string(
            fromByteCount: Int64(bytes),
            countStyle: .file
        )
    }
}

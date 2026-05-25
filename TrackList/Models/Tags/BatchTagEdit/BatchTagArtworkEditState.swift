//
//  BatchTagArtworkEditState.swift
//  TrackList
//
//  UI-состояние секции обложек в форме массового редактирования тегов.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

struct BatchTagArtworkEditState: Equatable {
    var action: BatchTagArtworkEditAction  /// Действие, выбранное пользователем для обложек.
    var newArtworkData: Data?              /// Данные новой выбранной обложки.
    let summary: BatchTagArtworkSummary    /// Сводная информация о текущих обложках выбранных треков.
    /// Сводная информация для первой карточки preview.
    var previewSummary: BatchTagArtworkPreviewSummary
    /// Первые элементы preview обложек.
    var previewItems: [BatchTagArtworkPreviewItem]
    /// Текущая выбранная цель действий с обложками.
    var selectedTarget: BatchTagArtworkActionTarget?
}

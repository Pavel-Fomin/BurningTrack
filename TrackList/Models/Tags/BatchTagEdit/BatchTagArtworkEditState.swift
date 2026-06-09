//
//  BatchTagArtworkEditState.swift
//  TrackList
//
//  UI-состояние секции обложек в форме массового редактирования тегов.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

/// Устаревшее UI-состояние действия с обложкой.
/// Сохраняется до перевода replace UI на действия с данными изображения.
enum BatchTagArtworkLegacyEditAction: Equatable {
    case keep
    case remove
    case replace
}

struct BatchTagArtworkEditState: Equatable {
    var action: BatchTagArtworkLegacyEditAction /// Устаревшее действие, используемое текущим UI.
    /// Общее действие с обложками для всей выбранной группы треков.
    var groupAction: BatchTagArtworkEditAction = .keep
    /// Индивидуальные действия с обложками по идентификаторам треков.
    var trackActions: [UUID: BatchTagArtworkEditAction] = [:]
    var newArtworkData: Data?              /// Данные новой выбранной обложки.
    let summary: BatchTagArtworkSummary    /// Сводная информация о текущих обложках выбранных треков.
    /// Сводная информация для первой карточки preview.
    var previewSummary: BatchTagArtworkPreviewSummary
    /// Первые элементы preview обложек.
    var previewItems: [BatchTagArtworkPreviewItem]
    /// Текущая выбранная цель действий с обложками.
    var selectedTarget: BatchTagArtworkActionTarget?

    /// Сохраняет действие с обложкой отдельно от текущего UI-выбора карточки.
    mutating func setAction(
        _ action: BatchTagArtworkEditAction,
        for target: BatchTagArtworkActionTarget
    ) {
        switch target {
        case .summary:
            groupAction = action
        case .track(let id):
            trackActions[id] = action
        }
    }

    /// Возвращает итоговое действие с обложкой для конкретного трека.
    func action(for trackId: UUID) -> BatchTagArtworkEditAction {
        trackActions[trackId] ?? groupAction
    }

    /// Есть ли несохранённые изменения действий с обложками.
    var hasChanges: Bool {
        if groupAction != .keep {
            return true
        }
        return trackActions.values.contains { $0 != .keep }
    }
}

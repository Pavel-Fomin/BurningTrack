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
    /// Общее действие с обложками для всей выбранной группы треков.
    var groupAction: BatchTagArtworkEditAction = .keep
    /// Индивидуальные действия с обложками по идентификаторам треков.
    var trackActions: [UUID: BatchTagArtworkEditAction] = [:]
    let summary: BatchTagArtworkSummary    /// Сводная информация о текущих обложках выбранных треков.
    /// Сводная информация для первой карточки preview.
    var previewSummary: BatchTagArtworkPreviewSummary
    /// Первые элементы preview обложек.
    var previewItems: [BatchTagArtworkPreviewItem]
    /// Текущая выбранная цель действий с обложками.
    var selectedTarget: BatchTagArtworkActionTarget?
    /// Количество обложек, которые не удалось сжать.
    var compressionFailureCount: Int = 0
    /// Идентификатор текущей операции сжатия.
    var activeCompressionId: UUID?

    /// Выполняется ли сжатие обложек.
    var isCompressing: Bool {
        activeCompressionId != nil
    }

    /// Сохраняет действие с обложкой отдельно от текущего UI-выбора карточки.
    mutating func setAction(
        _ action: BatchTagArtworkEditAction,
        for target: BatchTagArtworkActionTarget
    ) {
        switch target {
        case .summary:
            groupAction = action
            trackActions.removeAll()
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

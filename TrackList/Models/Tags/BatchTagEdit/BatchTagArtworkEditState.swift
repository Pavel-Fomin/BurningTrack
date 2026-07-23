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
    /// Идентификатор preview общей несохранённой замены объединяет запросы всех карточек.
    private var groupReplacementPreviewID: UUID?
    /// Идентификаторы preview индивидуальных несохранённых замен.
    private var trackReplacementPreviewIDs: [UUID: UUID] = [:]
    let summary: BatchTagArtworkSummary    /// Сводная информация о текущих обложках выбранных треков.
    /// Сводная информация для первой карточки preview.
    var previewSummary: BatchTagArtworkPreviewSummary
    /// Первые элементы preview обложек.
    var previewItems: [BatchTagArtworkPreviewItem]
    /// Текущая выбранная цель действий с обложками.
    var selectedTarget: BatchTagArtworkActionTarget?
    /// Прогресс подготовки обложек перед сохранением.
    var preparationProgress: BatchTagArtworkPreparationProgress?
    /// Количество обложек, которые не удалось сжать.
    var compressionFailureCount: Int = 0
    /// Идентификатор текущей операции сжатия.
    var activeCompressionId: UUID?

    /// Создаёт состояние секции, не раскрывая технические идентификаторы preview наружу.
    init(
        groupAction: BatchTagArtworkEditAction = .keep,
        trackActions: [UUID: BatchTagArtworkEditAction] = [:],
        summary: BatchTagArtworkSummary,
        previewSummary: BatchTagArtworkPreviewSummary,
        previewItems: [BatchTagArtworkPreviewItem],
        selectedTarget: BatchTagArtworkActionTarget?,
        preparationProgress: BatchTagArtworkPreparationProgress? = nil,
        compressionFailureCount: Int = 0,
        activeCompressionId: UUID? = nil
    ) {
        self.groupAction = groupAction
        self.trackActions = trackActions
        self.groupReplacementPreviewID = groupAction.isReplacement ? UUID() : nil
        self.trackReplacementPreviewIDs = Dictionary(
            uniqueKeysWithValues: trackActions.compactMap { trackId, action in
                action.isReplacement ? (trackId, UUID()) : nil
            }
        )
        self.summary = summary
        self.previewSummary = previewSummary
        self.previewItems = previewItems
        self.selectedTarget = selectedTarget
        self.preparationProgress = preparationProgress
        self.compressionFailureCount = compressionFailureCount
        self.activeCompressionId = activeCompressionId
    }

    /// Выполняется ли подготовка обложек перед сохранением.
    var isPreparing: Bool {
        preparationProgress != nil
    }

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
            trackReplacementPreviewIDs.removeAll()
            groupReplacementPreviewID = action.isReplacement ? UUID() : nil
        case .track(let id):
            trackActions[id] = action
            trackReplacementPreviewIDs[id] = action.isReplacement ? UUID() : nil
        }
    }

    /// Возвращает итоговое действие с обложкой для конкретного трека.
    func action(for trackId: UUID) -> BatchTagArtworkEditAction {
        trackActions[trackId] ?? groupAction
    }

    /// Возвращает стабильный идентификатор несохранённой замены для асинхронного preview.
    func replacementPreviewIdentifier(for trackId: UUID) -> UUID? {
        if let trackAction = trackActions[trackId] {
            guard trackAction.isReplacement else { return nil }
            return trackReplacementPreviewIDs[trackId]
        }

        guard groupAction.isReplacement else { return nil }
        return groupReplacementPreviewID
    }

    /// Есть ли несохранённые изменения действий с обложками.
    var hasChanges: Bool {
        if groupAction != .keep {
            return true
        }
        return trackActions.values.contains { $0 != .keep }
    }
}

private extension BatchTagArtworkEditAction {
    /// Показывает, содержит ли действие новые данные обложки.
    var isReplacement: Bool {
        if case .replace = self {
            return true
        }
        return false
    }
}

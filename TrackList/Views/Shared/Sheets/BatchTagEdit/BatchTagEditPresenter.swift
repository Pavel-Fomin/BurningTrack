//
//  BatchTagEditPresenter.swift
//  TrackList
//
//  Преобразует draft массового редактирования тегов в готовое presentation-состояние.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Формирует состояние Batch Tag Edit и сохраняет существующие контракты ToastEvent.
@MainActor
struct BatchTagEditPresenter {
    /// Общий presenter пользовательских сообщений приложения.
    private let toastPresenter: any ToastPresenting

    init(toastPresenter: any ToastPresenting) {
        self.toastPresenter = toastPresenter
    }

    /// Преобразует feature-local draft в данные, достаточные только для SwiftUI.
    func makeState(from flow: BatchTagEditFlow) -> BatchTagEditScreenState {
        BatchTagEditScreenState(
            phase: flow.phase,
            canSave: flow.canSave,
            displayedFields: makeDisplayedFields(from: flow),
            artwork: makeArtworkState(from: flow)
        )
    }

    /// Показывает прежний итог массового сохранения без переноса ToastManager во ViewModel.
    func present(_ result: BatchTagEditSaveResult) {
        if result.failedCount == 0 {
            toastPresenter.handle(.batchTagsUpdated(count: result.succeededCount))
        } else if result.succeededCount > 0 {
            toastPresenter.handle(
                .batchTagsPartiallyUpdated(
                    succeeded: result.succeededCount,
                    failed: result.failedCount
                )
            )
        } else {
            toastPresenter.handle(.batchTagsUpdateFailed(failed: result.failedCount))
        }
    }

    /// Сохраняет контракт ошибки, когда planner не смог построить план записи.
    func presentSaveValidationFailure(for flow: BatchTagEditFlow) {
        toastPresenter.handle(.batchTagsUpdateFailed(failed: flow.tracks.count))
    }

    /// Формирует поля для group-режима либо выбранного конкретного трека.
    private func makeDisplayedFields(
        from flow: BatchTagEditFlow
    ) -> [BatchTagEditFieldScreenState] {
        let fields = editableFields(from: flow)
        return fields.map { field in
            BatchTagEditFieldScreenState(
                field: field.field,
                value: field.value,
                placeholder: placeholder(for: field),
                emphasizesPlaceholder: field.summary == .mixed && field.action == .keep,
                showsClearButton: field.summary == .mixed && field.action == .keep
            )
        }
    }

    /// Возвращает готовые поля выбранного трека, не раскрывая override-слой View.
    private func editableFields(from flow: BatchTagEditFlow) -> [BatchTagFieldEditState] {
        guard case .track(let trackId) = flow.artwork.selectedTarget,
              let track = flow.tracks.first(where: { $0.trackId == trackId }) else {
            return flow.fields
        }

        return EditableTrackField.allCases.map { field in
            if let override = flow.trackFieldOverrides[trackId]?.fields[field] {
                return override
            }

            let value = track.values[field] ?? ""
            return BatchTagFieldEditState(
                field: field,
                action: .keep,
                value: value,
                summary: value.isEmpty ? .empty : .same(value)
            )
        }
    }

    /// Собирает presentation artwork с учётом локальных несохранённых действий.
    private func makeArtworkState(
        from flow: BatchTagEditFlow
    ) -> BatchTagEditArtworkScreenState {
        let cards = flow.artwork.previewItems.map { item in
            makeArtworkCard(item: item, artwork: flow.artwork)
        }
        let totalSize = cards.reduce(0) { partialResult, card in
            partialResult + artworkSize(for: card, artwork: flow.artwork)
        }

        return BatchTagEditArtworkScreenState(
            selectedTarget: flow.artwork.selectedTarget,
            summary: BatchTagEditArtworkSummaryScreenState(
                selectedCount: flow.artwork.previewSummary.selectedCount,
                formattedArtworkSize: BatchTagArtworkSizeFormatter.string(from: totalSize),
                isSelected: flow.artwork.selectedTarget == .summary
            ),
            cards: cards,
            compressionFailureText: flow.artwork.compressionFailureCount > 0
                ? BatchTagEditPresentationText.compressionFailureText(
                    for: flow.artwork.compressionFailureCount
                )
                : nil,
            preparationProgress: flow.artwork.preparationProgress,
            isCompressing: flow.artwork.isCompressing
        )
    }

    /// Формирует одну карточку без обращения к ArtworkProvider или runtime store.
    private func makeArtworkCard(
        item: BatchTagArtworkPreviewItem,
        artwork: BatchTagArtworkEditState
    ) -> BatchTagEditArtworkCardScreenState {
        let action = artwork.action(for: item.trackId)
        let artworkRequest: ArtworkRequest?
        let hasArtwork: Bool

        switch action {
        case .keep:
            artworkRequest = item.originalArtworkRequest
            hasArtwork = item.hasArtwork

        case .remove:
            artworkRequest = nil
            hasArtwork = false

        case .replace(let data):
            artworkRequest = artwork.replacementPreviewIdentifier(for: item.trackId).map {
                ArtworkRequest(
                    trackId: item.trackId,
                    artworkData: data,
                    purpose: .batchTagPreview,
                    sourceIdentifier: .transient(revision: $0)
                )
            }
            hasArtwork = true
        }

        return BatchTagEditArtworkCardScreenState(
            trackId: item.trackId,
            title: item.title,
            artworkRequest: artworkRequest,
            hasArtwork: hasArtwork,
            formattedArtworkSize: BatchTagArtworkSizeFormatter.string(
                from: artworkSize(for: item, action: action)
            ),
            isSelected: artwork.selectedTarget == .track(item.trackId)
        )
    }

    /// Возвращает размер результата текущего artwork-действия.
    private func artworkSize(
        for item: BatchTagArtworkPreviewItem,
        action: BatchTagArtworkEditAction
    ) -> Int {
        switch action {
        case .keep:
            return item.artworkSizeBytes ?? 0
        case .remove:
            return 0
        case .replace(let data):
            return data.count
        }
    }

    /// Извлекает размер из готовой карточки повторно по лёгкой идентичности трека.
    private func artworkSize(
        for card: BatchTagEditArtworkCardScreenState,
        artwork: BatchTagArtworkEditState
    ) -> Int {
        guard let item = artwork.previewItems.first(where: { $0.trackId == card.trackId }) else {
            return 0
        }
        return artworkSize(for: item, action: artwork.action(for: card.trackId))
    }

    /// Возвращает placeholder, видимый только для mixed поля в состоянии keep.
    private func placeholder(for field: BatchTagFieldEditState) -> String {
        guard field.action == .keep else { return "" }
        return field.summary == .mixed ? TagEditorPresentationText.mixedPlaceholder : ""
    }
}

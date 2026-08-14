//
//  BatchFilenameRenamePresenter.swift
//  TrackList
//
//  Преобразует draft массового переименования в presentation state.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Готовит все тексты, строки и UI-доступность Batch Filename Rename вне SwiftUI View.
@MainActor
struct BatchFilenameRenamePresenter {
    /// Собирает immutable снимок UI из feature-local mutable draft.
    func makeState(
        from draft: BatchFilenameRenameDraft
    ) -> BatchFilenameRenameScreenState {
        let isLoadingMetadata = draft.phase == .loadingMetadata
        let isBusy = draft.isPreparingMetadata || draft.isApplyingRename

        return BatchFilenameRenameScreenState(
            rows: makeRows(from: draft),
            selectedStrategy: draft.strategy,
            selectedStrategyTitle: selectedStrategyTitle(for: draft.strategy),
            isLoadingMetadata: isLoadingMetadata,
            isApplyingRename: draft.isApplyingRename,
            isBusy: isBusy,
            canApplyRename: canApplyRename(from: draft, isBusy: isBusy),
            canSelectStrategy: !isBusy,
            canRemoveTracks: !isBusy,
            isDismissDisabled: isBusy,
            preparationProgress: draft.isPreparingMetadata ? draft.preparationProgress : nil,
            applyingProgress: draft.isApplyingRename ? draft.applyingProgress : nil
        )
    }

    /// Показывает seed-имена до metadata, а затем подготовленные строки плана.
    private func makeRows(
        from draft: BatchFilenameRenameDraft
    ) -> [BatchFilenameRenameScreenState.Row] {
        if draft.items.isEmpty {
            return draft.tracks.map { track in
                BatchFilenameRenameScreenState.Row(
                    trackId: track.trackId,
                    fileName: track.currentFileName,
                    statusDescription: nil,
                    statusStyle: .neutral
                )
            }
        }

        return draft.items.map { item in
            BatchFilenameRenameScreenState.Row(
                trackId: item.trackId,
                fileName: displayedFileName(for: item),
                statusDescription: FileRenamePresentationText.statusDescription(for: item.status),
                statusStyle: statusStyle(for: item.status)
            )
        }
    }

    /// Ошибки metadata показывают исходное имя, а остальные ошибки — целевое.
    private func displayedFileName(for item: BatchFilenameRenameItem) -> String {
        switch item.status {
        case .ready,
             .renamed,
             .applyFailed,
             .trackIsPlaying,
             .fileAccessDenied:
            return item.targetFileName
        case .missingArtist,
             .missingTitle,
             .missingArtistAndTitle,
             .invalidTargetName:
            return item.currentFileName
        }
    }

    /// Преобразует domain-статус в единственный presentation-стиль строки.
    private func statusStyle(
        for status: BatchFilenameRenameStatus
    ) -> BatchFilenameRenameRowStatusStyle {
        switch status {
        case .renamed:
            return .success
        case .ready:
            return .neutral
        case .missingArtist,
             .missingTitle,
             .missingArtistAndTitle,
             .invalidTargetName,
             .applyFailed,
             .trackIsPlaying,
             .fileAccessDenied:
            return .error
        }
    }

    /// Возвращает текст выбранной стратегии без вычислений в View.
    private func selectedStrategyTitle(
        for strategy: FilenameRenameStrategy?
    ) -> String {
        switch strategy {
        case .artistTitle:
            return FileRenamePresentationText.strategyTitle(
                for: FilenameRenameStrategy.artistTitle
            )
        case .titleArtist:
            return FileRenamePresentationText.strategyTitle(
                for: FilenameRenameStrategy.titleArtist
            )
        case nil:
            return FileRenamePresentationText.chooseStrategyTitle
        }
    }

    /// Разрешает apply только для готовой стратегии и хотя бы одной ready-строки.
    private func canApplyRename(
        from draft: BatchFilenameRenameDraft,
        isBusy: Bool
    ) -> Bool {
        guard !isBusy,
              draft.phase != .loadingMetadata,
              draft.strategy != nil else {
            return false
        }

        return draft.items.contains { $0.status == .ready }
    }
}

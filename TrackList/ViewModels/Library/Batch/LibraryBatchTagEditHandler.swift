//
//  LibraryBatchTagEditHandler.swift
//  TrackList
//
//  Обрабатывает массовое редактирование тегов фонотеки.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

/// Обрабатывает массовое редактирование тегов фонотеки.
/// Не знает про selection и не управляет списком фонотеки.
@MainActor
final class LibraryBatchTagEditHandler {

    // MARK: - Dependencies

    private let sheetManager: SheetManager
    private let toastManager: ToastManager
    private let metadataLoader: BatchTagMetadataLoader
    private let saveExecutor: BatchTagEditSaveExecutor

    // MARK: - Init

    init(
        sheetManager: SheetManager? = nil,
        toastManager: ToastManager? = nil,
        metadataLoader: BatchTagMetadataLoader? = nil,
        saveExecutor: BatchTagEditSaveExecutor? = nil
    ) {
        self.sheetManager = sheetManager ?? .shared
        self.toastManager = toastManager ?? .shared
        self.metadataLoader = metadataLoader ?? BatchTagMetadataLoader()
        self.saveExecutor = saveExecutor ?? BatchTagEditSaveExecutor()
    }

    // MARK: - Public

    /// Запускает flow массового редактирования тегов.
    func startEdit(with pendingAction: PendingBulkTrackAction) {
        let loadingFlow = makeLoadingFlow(pendingAction: pendingAction)

        sheetManager.presentBatchTagEdit(
            flow: loadingFlow,
            onSave: { [weak self] in
                await self?.applyEdit()
            }
        )

        Task { [weak self, pendingAction] in
            guard let self else { return }

            let loadedFlow = await metadataLoader.loadFlow(
                pendingAction: pendingAction
            )
            guard sheetManager.batchTagEditFlow.pendingAction?.trackIDs == pendingAction.trackIDs else { return }
            sheetManager.batchTagEditFlow = loadedFlow
        }
    }

    // MARK: - Private

    /// Сохраняет массовые изменения тегов.
    private func applyEdit() async {
        let flow = sheetManager.batchTagEditFlow
        let pendingAction = flow.pendingAction
        let selectedTarget = flow.artwork.selectedTarget

        guard let pendingAction else {
            toastManager.handle(.batchTagsUpdateFailed(failed: flow.tracks.count))
            return
        }

        do {
            let plan = try BatchTagEditSavePlanner.makePlan(from: flow)
            let result = await saveExecutor.execute(plan: plan)

            handleSaveResult(result)

            if result.succeededCount > 0 {
                await reloadFlowAfterSave(
                    pendingAction: pendingAction,
                    selectedTarget: selectedTarget
                )
            }
        } catch {
            toastManager.handle(.batchTagsUpdateFailed(failed: flow.tracks.count))
        }
    }

    /// Обновляет данные открытого sheet массового редактирования тегов после сохранения.
    private func reloadFlowAfterSave(
        pendingAction: PendingBulkTrackAction,
        selectedTarget: BatchTagArtworkActionTarget?
    ) async {
        let reloadedFlow = await metadataLoader.loadFlow(
            pendingAction: pendingAction
        )

        guard sheetManager.batchTagEditFlow.pendingAction?.trackIDs == pendingAction.trackIDs else { return }

        var updatedFlow = reloadedFlow
        updatedFlow.artwork.selectedTarget = selectedTarget ?? .summary
        updatedFlow.phase = .editing
        sheetManager.batchTagEditFlow = updatedFlow
    }

    /// Создаёт loading flow для немедленного открытия sheet.
    private func makeLoadingFlow(
        pendingAction: PendingBulkTrackAction
    ) -> BatchTagEditFlow {
        BatchTagEditFlow(
            pendingAction: pendingAction,
            phase: .loadingMetadata,
            tracks: [],
            fields: [],
            trackFieldOverrides: [:],
            artwork: BatchTagArtworkEditState(
                summary: .none,
                previewSummary: BatchTagArtworkPreviewSummary(
                    selectedCount: pendingAction.trackIDs.count,
                    artworkCount: 0,
                    missingArtworkCount: pendingAction.trackIDs.count
                ),
                previewItems: [],
                selectedTarget: nil
            )
        )
    }

    /// Показывает результат массового сохранения тегов.
    private func handleSaveResult(_ result: BatchTagEditSaveResult) {
        if result.failedCount == 0 {
            toastManager.handle(.batchTagsUpdated(count: result.succeededCount))
        } else if result.succeededCount > 0 {
            toastManager.handle(
                .batchTagsPartiallyUpdated(
                    succeeded: result.succeededCount,
                    failed: result.failedCount
                )
            )
        } else {
            toastManager.handle(.batchTagsUpdateFailed(failed: result.failedCount))
        }
    }
}

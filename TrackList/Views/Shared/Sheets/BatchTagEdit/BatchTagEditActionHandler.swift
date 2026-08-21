//
//  BatchTagEditActionHandler.swift
//  TrackList
//
//  Выполняет операции feature Batch Tag Edit вне SwiftUI View.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Подготовленные данные одной artwork для фонового сжатия.
struct BatchTagArtworkCompressionSource: Sendable {
    /// Идентификатор трека-владельца artwork.
    let trackId: UUID
    /// Исходные байты artwork.
    let data: Data
}

/// Результат сжатия с сохранением частичных ошибок по отдельным трекам.
struct BatchTagArtworkCompressionOutcome: Sendable {
    /// Успешно сжатые artwork, готовые к записи в draft.
    let replacements: [BatchTagArtworkCompressionSource]
    /// Количество artwork, которые не удалось подготовить или сжать.
    let failureCount: Int
}

/// Выполняет capability-операции сценария Batch Tag Edit без ссылок на SwiftUI.
@MainActor
final class BatchTagEditActionHandler {
    /// Загружает исходный draft выбранных треков.
    private let metadataLoader: any BatchTagEditMetadataLoading
    /// Выполняет сохранение уже подготовленного плана.
    private let saveExecutor: any BatchTagEditSaveExecuting
    /// Даёт актуальную artwork для сжатия исходного состояния.
    private let artworkDataProvider: any BatchTagArtworkDataProviding
    /// Нормализует выбранную replacement artwork.
    private let artworkPreparer: any BatchTagArtworkPreparing
    /// Сжимает artwork выбранным domain-алгоритмом.
    private let artworkCompressor: any BatchTagArtworkCompressing
    /// Показывает сохранённые контракты ToastEvent.
    private let presenter: BatchTagEditPresenter
    /// Управляет общим lifecycle sheet.
    private let router: any BatchTagEditRouting

    init(
        metadataLoader: any BatchTagEditMetadataLoading,
        saveExecutor: any BatchTagEditSaveExecuting,
        artworkDataProvider: any BatchTagArtworkDataProviding,
        artworkPreparer: any BatchTagArtworkPreparing,
        artworkCompressor: any BatchTagArtworkCompressing,
        presenter: BatchTagEditPresenter,
        router: any BatchTagEditRouting
    ) {
        self.metadataLoader = metadataLoader
        self.saveExecutor = saveExecutor
        self.artworkDataProvider = artworkDataProvider
        self.artworkPreparer = artworkPreparer
        self.artworkCompressor = artworkCompressor
        self.presenter = presenter
        self.router = router
    }

    /// Загружает draft для зафиксированного route payload.
    func load(pendingAction: PendingBulkTrackAction) async -> BatchTagEditFlow {
        await metadataLoader.loadFlow(pendingAction: pendingAction)
    }

    /// Строит план и выполняет запись; presentation сохраняется у ViewModel через Presenter.
    func save(flow: BatchTagEditFlow) async -> BatchTagEditSaveResult? {
        do {
            let plan = try BatchTagEditSavePlanner.makePlan(from: flow)
            return await saveExecutor.execute(plan: plan)
        } catch {
            presenter.presentSaveValidationFailure(for: flow)
            return nil
        }
    }

    /// Закрывает активный feature через общий SheetManager lifecycle.
    func close(routeID: UUID) {
        router.dismissBatchTagEdit(routeID)
    }

    /// Подготавливает выбранные пользователем данные artwork для несохранённого draft.
    func prepareReplacementArtwork(data: Data) async throws -> Data {
        try await artworkPreparer.prepareReplacementArtwork(data: data)
    }

    /// Собирает исходные artwork на главном акторе перед запуском фонового сжатия.
    func makeCompressionPreparation(
        for target: BatchTagArtworkActionTarget,
        in flow: BatchTagEditFlow
    ) -> BatchTagArtworkCompressionOutcome {
        let trackIDs: [UUID]
        switch target {
        case .summary:
            trackIDs = flow.artwork.previewItems.map(\.trackId)
        case .track(let trackId):
            trackIDs = [trackId]
        }

        var sources: [BatchTagArtworkCompressionSource] = []
        var failureCount = 0
        for trackId in trackIDs {
            guard let data = sourceArtworkData(for: trackId, in: flow) else {
                failureCount += 1
                continue
            }
            sources.append(BatchTagArtworkCompressionSource(trackId: trackId, data: data))
        }

        return BatchTagArtworkCompressionOutcome(
            replacements: sources,
            failureCount: failureCount
        )
    }

    /// Сжимает все доступные artwork, не прерывая batch при ошибке одного трека.
    func compressArtwork(
        _ sources: [BatchTagArtworkCompressionSource],
        option: BatchArtworkCompressionOption,
        initialFailureCount: Int
    ) async -> BatchTagArtworkCompressionOutcome {
        var replacements: [BatchTagArtworkCompressionSource] = []
        var failureCount = initialFailureCount

        for source in sources {
            guard !Task.isCancelled else {
                return BatchTagArtworkCompressionOutcome(
                    replacements: replacements,
                    failureCount: failureCount
                )
            }

            do {
                let data = try await artworkCompressor.compressArtwork(
                    data: source.data,
                    option: option
                )
                replacements.append(
                    BatchTagArtworkCompressionSource(trackId: source.trackId, data: data)
                )
            } catch {
                // Ошибка одного трека не останавливает сжатие остальных artwork.
                failureCount += 1
            }
        }

        return BatchTagArtworkCompressionOutcome(
            replacements: replacements,
            failureCount: failureCount
        )
    }

    /// Возвращает replacement либо актуальную исходную artwork для выбранного трека.
    private func sourceArtworkData(
        for trackId: UUID,
        in flow: BatchTagEditFlow
    ) -> Data? {
        switch flow.artwork.action(for: trackId) {
        case .keep:
            return artworkDataProvider.snapshot(forTrackId: trackId)?.artworkData
        case .remove:
            return nil
        case .replace(let data):
            return data
        }
    }
}

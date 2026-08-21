//
//  BatchTagEditFlowProtocols.swift
//  TrackList
//
//  Узкие контракты зависимостей сценария массового редактирования тегов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Foundation

/// Открывает и закрывает Batch Tag Edit через общий lifecycle SheetManager.
@MainActor
protocol BatchTagEditRouting: AnyObject {
    /// Открывает новый неизменяемый route массового редактирования тегов.
    func presentBatchTagEdit(pendingAction: PendingBulkTrackAction)
    /// Закрывает только route Batch Tag Edit с переданной идентичностью.
    func dismissBatchTagEdit(_ routeID: UUID)
}

/// Загружает исходный draft выбранных треков без знания UI feature.
@MainActor
protocol BatchTagEditMetadataLoading {
    /// Возвращает подготовленный рабочий draft для зафиксированного batch-действия.
    func loadFlow(pendingAction: PendingBulkTrackAction) async -> BatchTagEditFlow
}

/// Выполняет уже подготовленный план массовой записи тегов.
/// Общая команда стартует на MainActor, сохраняя единую точку пользовательского намерения.
@MainActor
protocol BatchTagEditSaveExecuting {
    /// Последовательно применяет команды плана и возвращает общий результат.
    func execute(plan: BatchTagEditSavePlan) async -> BatchTagEditSaveResult
}

/// Предоставляет актуальные данные artwork для операции сжатия.
@MainActor
protocol BatchTagArtworkDataProviding: AnyObject {
    /// Возвращает последний доступный runtime snapshot трека.
    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot?
}

/// Подготавливает новую replacement artwork вне SwiftUI View.
/// Stateless adapter безопасно пересекает async-границу, передавая только Data.
protocol BatchTagArtworkPreparing: Sendable {
    /// Нормализует выбранное пользователем изображение.
    func prepareReplacementArtwork(data: Data) async throws -> Data
}

/// Сжимает artwork с выбранным ограничением размера вне SwiftUI View.
/// Stateless adapter безопасно пересекает async-границу, передавая только Data.
protocol BatchTagArtworkCompressing: Sendable {
    /// Возвращает JPEG-данные artwork после сжатия.
    func compressArtwork(
        data: Data,
        option: BatchArtworkCompressionOption
    ) async throws -> Data
}

/// Production-адаптер существующего общего сервиса подготовки artwork.
struct BatchTagArtworkPreparer: Sendable, BatchTagArtworkPreparing {
    /// Применяет заданные feature параметры нормализации замены обложки.
    func prepareReplacementArtwork(data: Data) async throws -> Data {
        try await ArtworkPreparationService.prepare(
            ArtworkPreparationRequest(
                imageData: data,
                maxPixelSize: 1024,
                compressionQuality: 0.85
            )
        )
    }
}

/// Production-адаптер существующего domain-компрессора artwork.
struct BatchTagArtworkCompressionService: Sendable, BatchTagArtworkCompressing {
    /// Делегирует сжатие текущему domain-алгоритму без изменения его семантики.
    func compressArtwork(
        data: Data,
        option: BatchArtworkCompressionOption
    ) async throws -> Data {
        try await BatchTagArtworkCompressor.compress(data: data, option: option)
    }
}

// MARK: - Адаптеры production-слоя

extension BatchTagMetadataLoader: BatchTagEditMetadataLoading {}

extension BatchTagEditSaveExecutor: BatchTagEditSaveExecuting {}

extension TrackRuntimeStore: BatchTagArtworkDataProviding {}

extension SheetManager: BatchTagEditRouting {
    /// Открывает route без переноса mutable feature-state в SheetManager.
    func presentBatchTagEdit(pendingAction: PendingBulkTrackAction) {
        present(
            .batchTagEdit(
                BatchTagEditSheetData(
                    id: UUID(),
                    pendingAction: pendingAction
                )
            )
        )
    }

}

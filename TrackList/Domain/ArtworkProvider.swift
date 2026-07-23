//
//  ArtworkProvider.swift
//  TrackList
//
//  Каноничная подсистема асинхронной подготовки и кэширования обложек.
//
//  Ответственность:
//  — объединить запросы одной исходной обложки;
//  — хранить положительный и отрицательный кэши;
//  — передать ImageIO общей ограниченной рабочей очереди;
//  — не допустить возврат устаревшего результата после инвалидирования.
//
//  Created by PavelFomin on 09.01.2026.
//

import Foundation
import UIKit

/// Функция подготовки позволяет проверять кэширование без реального обращения к ImageIO.
typealias ArtworkImagePreparation = @Sendable (Data, ArtworkSizeClass) async -> UIImage?

/// Единственный владелец жизненного цикла подготовки обложек.
actor ArtworkProvider {
    static let shared = ArtworkProvider()

    /// Ограниченный положительный кэш удерживает не более 64 МиБ распакованных пикселей.
    private let positiveCache: any ArtworkPositiveImageCaching
    /// Отрицательный кэш запрещает повторное обращение к ImageIO для повреждённого источника.
    private var failedSourceIdentifiers: Set<ArtworkSourceIdentifier> = []
    /// На один составной ключ источника и класса размера существует не более одной операции подготовки.
    private var inFlightByCacheKey: [ArtworkCacheKey: InFlightPreparation] = [:]
    /// Поколение источника защищает от устаревшего результата после точечного сброса.
    private var generationBySourceIdentifier: [ArtworkSourceIdentifier: UInt64] = [:]
    /// Связывает исходную обложку с треком, чтобы инвалидирование не зависело от UUID данных.
    private var sourceIdentifiersByTrackId: [UUID: Set<ArtworkSourceIdentifier>] = [:]
    /// Общее поколение защищает от устаревших результатов после полной очистки.
    private var cacheGeneration: UInt64 = 0
    /// Внедряемая функция всегда выполняет тяжёлую работу вне actor и главного потока.
    private let prepareImage: ArtworkImagePreparation

    /// Создаёт provider с подготовкой на общей ограниченной очереди.
    init(
        prepareImage: @escaping ArtworkImagePreparation = { data, sizeClass in
            await ArtworkProcessingQueue.shared.prepareImage(
                from: data,
                sizeClass: sizeClass
            )
        },
        positiveCache: any ArtworkPositiveImageCaching = ArtworkPositiveImageCache()
    ) {
        self.prepareImage = prepareImage
        self.positiveCache = positiveCache
    }

    /// Возвращает готовую обложку асинхронно, объединяя все конкурентные запросы источника.
    func image(for request: ArtworkRequest) async -> UIImage? {
        let key = ArtworkCacheKey(
            sourceIdentifier: request.sourceIdentifier,
            sizeClass: request.sizeClass
        )

        sourceIdentifiersByTrackId[request.trackId, default: []]
            .insert(request.sourceIdentifier)

        if let cachedImage = positiveCache.image(for: key) {
            return cachedImage
        }

        guard !failedSourceIdentifiers.contains(request.sourceIdentifier) else {
            return nil
        }

        guard let artworkData = request.artworkData, !artworkData.isEmpty else {
            return nil
        }

        if let preparation = inFlightByCacheKey[key] {
            let result = await preparation.task.value
            return await resolve(
                result,
                preparation: preparation,
                requestedKey: key
            )
        }

        let preparation = makePreparation(
            key: key,
            artworkData: artworkData
        )
        inFlightByCacheKey[key] = preparation

        let result = await preparation.task.value
        return await resolve(
            result,
            preparation: preparation,
            requestedKey: key
        )
    }

    /// Сбрасывает оба кэша и выполняющуюся задачу сохранённой обложки трека.
    func invalidate(trackId: UUID) {
        let sourceIdentifiers = sourceIdentifiersByTrackId[trackId] ?? []
        sourceIdentifiersByTrackId.removeValue(forKey: trackId)
        for sourceIdentifier in sourceIdentifiers {
            invalidate(sourceIdentifier: sourceIdentifier)
        }
    }

    /// Полностью очищает положительный, отрицательный и выполняющийся кэши.
    func removeAll() {
        cacheGeneration &+= 1
        positiveCache.removeAllImages()
        failedSourceIdentifiers.removeAll()

        for preparation in inFlightByCacheKey.values {
            preparation.task.cancel()
        }
        inFlightByCacheKey.removeAll()
        generationBySourceIdentifier.removeAll()
        sourceIdentifiersByTrackId.removeAll()
    }

    /// Создаёт единственную задачу подготовки для источника и канонического класса размера.
    private func makePreparation(
        key: ArtworkCacheKey,
        artworkData: Data
    ) -> InFlightPreparation {
        let token = UUID()
        let sourceGeneration = generationBySourceIdentifier[key.sourceIdentifier, default: 0]
        let currentCacheGeneration = cacheGeneration
        let prepareImage = prepareImage
        let sizeClass = key.sizeClass

        let task = Task<UIImage?, Never> {
            guard !Task.isCancelled else { return nil }
            return await prepareImage(artworkData, sizeClass)
        }

        return InFlightPreparation(
            token: token,
            key: key,
            sourceGeneration: sourceGeneration,
            cacheGeneration: currentCacheGeneration,
            task: task
        )
    }

    /// Завершает общую задачу и возвращает результат всем назначениям одного класса размера.
    private func resolve(
        _ image: UIImage?,
        preparation: InFlightPreparation,
        requestedKey: ArtworkCacheKey
    ) async -> UIImage? {
        let currentSourceGeneration = generationBySourceIdentifier[
            preparation.key.sourceIdentifier,
            default: 0
        ]

        guard preparation.cacheGeneration == cacheGeneration,
              preparation.sourceGeneration == currentSourceGeneration else {
            return nil
        }

        if inFlightByCacheKey[preparation.key]?.token == preparation.token {
            inFlightByCacheKey[preparation.key] = nil

            if let image {
                positiveCache.store(
                    image,
                    for: preparation.key,
                    cost: ArtworkImageMemoryCost.value(for: image)
                )
            } else {
                failedSourceIdentifiers.insert(preparation.key.sourceIdentifier)
            }
        }

        return positiveCache.image(for: requestedKey)
    }

    /// Точечно очищает оба кэша и отменяет ожидание устаревшего результата источника.
    private func invalidate(sourceIdentifier: ArtworkSourceIdentifier) {
        generationBySourceIdentifier[sourceIdentifier, default: 0] &+= 1
        failedSourceIdentifiers.remove(sourceIdentifier)

        for sizeClass in ArtworkSizeClass.allCases {
            let key = ArtworkCacheKey(
                sourceIdentifier: sourceIdentifier,
                sizeClass: sizeClass
            )
            positiveCache.removeImage(for: key)
            inFlightByCacheKey[key]?.task.cancel()
            inFlightByCacheKey[key] = nil
        }

    }

}

/// Описание общей выполняющейся задачи одного исходного изображения.
private struct InFlightPreparation {
    let token: UUID
    let key: ArtworkCacheKey
    let sourceGeneration: UInt64
    let cacheGeneration: UInt64
    let task: Task<UIImage?, Never>
}

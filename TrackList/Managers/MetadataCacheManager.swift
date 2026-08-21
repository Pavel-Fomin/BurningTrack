//
//  MetadataCacheManager.swift
//  TrackList
//
//  Технический runtime-кэш сырых метаданных с actor-координацией операций.
//  Используется как внутренний слой чтения для сборки TrackRuntimeSnapshot.
//
//  Created by Pavel Fomin on 02.08.2025.
//

import Combine
import Foundation

/// Публикует только presentation-сигнал инвалидации, а raw cache оставляет вне MainActor.
@MainActor
final class TrackMetadataCacheManager: ObservableObject {
    static let shared = TrackMetadataCacheManager()

    /// Публикуется синхронно с завершением logical invalidation.
    /// Presentation-потребители могут пересобрать производные данные, не получая доступа к raw cache.
    @Published private(set) var revision: Int = 0

    private let storage: MetadataCacheStorage

    private init() {
        storage = MetadataCacheStorage()
    }

    /// Позволяет controlled XCTest подменить только границу чтения метаданных.
    init(
        metadataParser: @escaping MetadataCacheStorage.MetadataParser,
        maximumConcurrentLoads: Int = MetadataCacheStorage.defaultMaximumConcurrentLoads
    ) {
        storage = MetadataCacheStorage(
            metadataParser: metadataParser,
            maximumConcurrentLoads: maximumConcurrentLoads
        )
    }

    // MARK: - Быстрый доступ к кэшу без запуска парсинга

    /// Возвращает сырые метаданные из технического кэша без чтения файла.
    ///
    /// Важно:
    /// - не является источником истины для UI;
    /// - actor-владелец исключает синхронный небезопасный доступ к NSCache.
    func loadMetadataFromCache(url: URL) async -> CachedMetadata? {
        await storage.loadMetadataFromCache(url: url)
    }

    // MARK: - Инвалидация кэша

    /// Удаляет метаданные трека из технического кэша.
    /// Используется после изменения тегов, обложки или переименования файла.
    ///
    /// После возврата cache, generation и in-flight запись уже логически инвалидированы,
    /// а revision уже отражает это изменение на MainActor.
    func invalidate(url: URL) async {
        await storage.invalidate(url: url)
        revision &+= 1
    }

    /// Полностью очищает кэш, например при смене политики чтения тегов.
    ///
    /// После возврата все старые операции отменены и не могут повторно заполнить raw cache.
    func invalidateAll() async {
        await storage.invalidateAll()
        revision &+= 1
    }

    // MARK: - Загрузка тегов

    /// Загружает и кэширует полный каноничный набор сырых runtime-метаданных файла.
    ///
    /// Параметр includeArtwork намеренно отсутствует: один URL соответствует одному полному raw result,
    /// поэтому cache hit не может вернуть семантически неполные metadata после другого запроса.
    func loadMetadata(for url: URL) async -> CachedMetadata? {
        await storage.loadMetadata(for: url)
    }

    // MARK: - Внутренний тип, представляющий закэшированные метаданные

    final class CachedMetadata: NSObject, @unchecked Sendable {

        let title: String?
        let artist: String?
        let duration: Double?

        /// Сырые данные обложки (JPEG / PNG и т.п.)
        /// - технический raw-cache, а не главный источник истины для UI
        /// - не декодируется здесь
        /// - не даунсемплится здесь
        /// - используется при сборке TrackRuntimeSnapshot и ArtworkProvider'ом
        let artworkData: Data?
        /// Стабильная идентичность raw-обложки, рассчитанная до передачи в UI.
        let artworkSourceIdentifier: ArtworkSourceIdentifier?

        init(
            title: String?,
            artist: String?,
            duration: Double?,
            artworkData: Data?,
            artworkSourceIdentifier: ArtworkSourceIdentifier?
        ) {
            self.title = title
            self.artist = artist
            self.duration = duration
            self.artworkData = artworkData
            self.artworkSourceIdentifier = artworkSourceIdentifier
        }
    }
}

/// Единственный владелец mutable raw cache lifecycle.
/// Actor изолирует NSCache, in-flight операции, generations и очередь лимитера одним контрактом.
actor MetadataCacheStorage {
    typealias MetadataParser = @Sendable (URL) async -> TrackMetadataCacheManager.CachedMetadata?

    static let defaultMaximumConcurrentLoads = 6

    private struct MetadataOperationID: Hashable, Sendable {
        let rawValue: UUID

        init() {
            rawValue = UUID()
        }
    }

    private struct MetadataConsumerID: Hashable, Sendable {
        let rawValue: UUID

        init() {
            rawValue = UUID()
        }
    }

    private struct MetadataGeneration: Equatable {
        let global: UInt64
        let url: UInt64
    }

    private struct InFlightOperation {
        let id: MetadataOperationID
        let generation: MetadataGeneration
        let task: Task<TrackMetadataCacheManager.CachedMetadata?, Never>
        var consumerIDs: Set<MetadataConsumerID>
    }

    private struct WaitingOperation {
        let url: URL
        let continuation: CheckedContinuation<Bool, Never>
    }

    private let cache = NSCache<NSURL, TrackMetadataCacheManager.CachedMetadata>()
    private let metadataParser: MetadataParser
    private let maximumConcurrentLoads: Int

    private var inFlight: [URL: InFlightOperation] = [:]
    private var globalGeneration: UInt64 = 0
    private var urlGenerations: [URL: UInt64] = [:]

    private var runningOperationIDs = Set<MetadataOperationID>()
    private var waitingOperations: [MetadataOperationID: WaitingOperation] = [:]
    private var waitingOrder: [MetadataOperationID] = []

    init(
        metadataParser: @escaping MetadataParser = MetadataCacheStorage.productionMetadataParser,
        maximumConcurrentLoads: Int = MetadataCacheStorage.defaultMaximumConcurrentLoads
    ) {
        self.metadataParser = metadataParser
        self.maximumConcurrentLoads = max(1, maximumConcurrentLoads)

        cache.countLimit = 100
        cache.totalCostLimit = 30 * 1024 * 1024 // 30 MB
    }

    // MARK: - Чтение и дедупликация

    /// Возвращает только уже подготовленное значение, не создавая parser operation.
    func loadMetadataFromCache(
        url: URL
    ) -> TrackMetadataCacheManager.CachedMetadata? {
        cache.object(forKey: url as NSURL)
    }

    /// Резервирует in-flight запись до первого suspension point и присоединяет consumer к общему результату.
    func loadMetadata(
        for url: URL
    ) async -> TrackMetadataCacheManager.CachedMetadata? {
        guard !Task.isCancelled else {
            return nil
        }

        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        let consumerID = MetadataConsumerID()
        let operation: InFlightOperation

        if var existingOperation = inFlight[url] {
            existingOperation.consumerIDs.insert(consumerID)
            inFlight[url] = existingOperation
            operation = existingOperation
        } else {
            let operationID = MetadataOperationID()
            let generation = currentGeneration(for: url)

            // Операция создаётся и сразу записывается до await task.value.
            // Поэтому второй запрос того же URL всегда увидит этот token, даже если первый ждёт slot лимитера.
            let task = Task<TrackMetadataCacheManager.CachedMetadata?, Never> { [weak self] in
                guard let self else {
                    return nil
                }

                return await self.executeOperation(
                    id: operationID,
                    url: url,
                    generation: generation
                )
            }

            let newOperation = InFlightOperation(
                id: operationID,
                generation: generation,
                task: task,
                consumerIDs: [consumerID]
            )
            inFlight[url] = newOperation
            operation = newOperation
        }

        return await waitForOperation(
            operation,
            url: url,
            consumerID: consumerID
        )
    }

    // MARK: - Инвалидация

    /// После возврата старое поколение и связанная in-flight операция уже не могут записать cache.
    func invalidate(url: URL) {
        urlGenerations[url, default: 0] &+= 1
        cache.removeObject(forKey: url as NSURL)
        cancelOperation(for: url)
    }

    /// После возврата все старые поколения и in-flight операции уже логически недействительны.
    func invalidateAll() {
        globalGeneration &+= 1
        cache.removeAllObjects()

        let operations = inFlight.values
        inFlight.removeAll()

        for operation in operations {
            operation.task.cancel()
        }
    }

    // MARK: - Выполнение parser operation

    private func executeOperation(
        id: MetadataOperationID,
        url: URL,
        generation: MetadataGeneration
    ) async -> TrackMetadataCacheManager.CachedMetadata? {
        guard await acquireSlot(for: id) else {
            finishWithoutResult(id: id, url: url)
            return nil
        }

        guard markOperationRunning(id: id, url: url) else {
            releaseSlot()
            return nil
        }

        defer {
            runningOperationIDs.remove(id)
            releaseSlot()
        }

        let parsedMetadata = await metadataParser(url)
        return finishOperation(
            id: id,
            url: url,
            generation: generation,
            metadata: parsedMetadata
        )
    }

    /// Проверяет generation и записывает результат в рамках одной actor-isolated операции.
    /// Между проверкой и NSCache.store не существует suspension point, поэтому invalidate не создаёт TOCTOU.
    private func finishOperation(
        id: MetadataOperationID,
        url: URL,
        generation: MetadataGeneration,
        metadata: TrackMetadataCacheManager.CachedMetadata?
    ) -> TrackMetadataCacheManager.CachedMetadata? {
        guard let currentOperation = inFlight[url],
              currentOperation.id == id else {
            return nil
        }

        // Token не позволяет late completion старой операции удалить или заменить новый in-flight запрос того же URL.
        inFlight[url] = nil

        guard generation == currentGeneration(for: url),
              !Task.isCancelled,
              let metadata else {
            return nil
        }

        cache.setObject(
            metadata,
            forKey: url as NSURL,
            cost: metadata.artworkData?.count ?? 1
        )
        return metadata
    }

    private func finishWithoutResult(
        id: MetadataOperationID,
        url: URL
    ) {
        guard inFlight[url]?.id == id else {
            return
        }

        inFlight[url] = nil
    }

    private func markOperationRunning(
        id: MetadataOperationID,
        url: URL
    ) -> Bool {
        guard inFlight[url]?.id == id else {
            return false
        }

        runningOperationIDs.insert(id)
        return true
    }

    // MARK: - Consumer cancellation

    private func waitForOperation(
        _ operation: InFlightOperation,
        url: URL,
        consumerID: MetadataConsumerID
    ) async -> TrackMetadataCacheManager.CachedMetadata? {
        await withTaskCancellationHandler(operation: {
            let result = await operation.task.value
            removeConsumer(
                consumerID,
                from: url,
                operationID: operation.id
            )
            return result
        }, onCancel: {
            Task { [weak self] in
                await self?.removeConsumer(
                    consumerID,
                    from: url,
                    operationID: operation.id
                )
            }
        })
    }

    /// Отмена одного consumer не прерывает уже работающий shared parser, если другой consumer присоединится позднее.
    /// Операция, которая ещё ждёт limiter и осталась без consumer, отменяется до получения slot.
    private func removeConsumer(
        _ consumerID: MetadataConsumerID,
        from url: URL,
        operationID: MetadataOperationID
    ) {
        guard var operation = inFlight[url], operation.id == operationID else {
            return
        }

        guard operation.consumerIDs.remove(consumerID) != nil else {
            return
        }

        guard operation.consumerIDs.isEmpty else {
            inFlight[url] = operation
            return
        }

        guard !runningOperationIDs.contains(operationID) else {
            inFlight[url] = operation
            return
        }

        inFlight[url] = nil
        operation.task.cancel()
    }

    // MARK: - Bounded concurrency

    /// Выдаёт slot только текущей операции. Cancelled waiter удаляется из очереди и получает false ровно один раз.
    private func acquireSlot(for operationID: MetadataOperationID) async -> Bool {
        guard !Task.isCancelled else {
            return false
        }

        if runningOperationIDs.count < maximumConcurrentLoads {
            return true
        }

        return await withTaskCancellationHandler(operation: {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: false)
                    return
                }

                guard let url = inFlight.first(where: { $0.value.id == operationID })?.key else {
                    continuation.resume(returning: false)
                    return
                }

                waitingOperations[operationID] = WaitingOperation(
                    url: url,
                    continuation: continuation
                )
                waitingOrder.append(operationID)
            }
        }, onCancel: {
            Task { [weak self] in
                await self?.cancelWaitingOperation(id: operationID)
            }
        })
    }

    private func releaseSlot() {
        while !waitingOrder.isEmpty {
            let operationID = waitingOrder.removeFirst()

            guard let waitingOperation = waitingOperations.removeValue(forKey: operationID) else {
                continue
            }

            guard let operation = inFlight[waitingOperation.url],
                  operation.id == operationID,
                  !operation.task.isCancelled else {
                waitingOperation.continuation.resume(returning: false)
                continue
            }

            waitingOperation.continuation.resume(returning: true)
            return
        }
    }

    private func cancelWaitingOperation(id: MetadataOperationID) {
        guard let waitingOperation = waitingOperations.removeValue(forKey: id) else {
            return
        }

        waitingOrder.removeAll { $0 == id }
        waitingOperation.continuation.resume(returning: false)
    }

    // MARK: - Вспомогательное

    private func cancelOperation(for url: URL) {
        guard let operation = inFlight.removeValue(forKey: url) else {
            return
        }

        operation.task.cancel()
    }

    private func currentGeneration(for url: URL) -> MetadataGeneration {
        MetadataGeneration(
            global: globalGeneration,
            url: urlGenerations[url, default: 0]
        )
    }

    private static let productionMetadataParser: MetadataParser = { url in
        guard let metadata = try? await RuntimeMetadataParser.parseMetadata(from: url) else {
            return nil
        }

        return TrackMetadataCacheManager.CachedMetadata(
            title: metadata.title,
            artist: metadata.artist,
            duration: metadata.duration,
            artworkData: metadata.artworkData,
            artworkSourceIdentifier: metadata.artworkSourceIdentifier
        )
    }
}

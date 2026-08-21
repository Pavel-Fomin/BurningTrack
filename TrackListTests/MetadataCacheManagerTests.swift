//
//  MetadataCacheManagerTests.swift
//  TrackList
//
//  Controlled XCTest для actor-координации raw metadata cache.
//
//  Created by Pavel Fomin on 20.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class MetadataCacheManagerTests: XCTestCase {

    func testConcurrentRequestsForSameURLShareSingleParserOperation() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser)
        let url = makeURL("same-url")
        let expected = makeMetadata(title: "Canonical")

        let first = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(1)

        let second = Task { await manager.loadMetadata(for: url) }
        await Task.yield()

        await parser.completeNext(for: url, with: expected)

        let firstResult = await first.value
        let secondResult = await second.value
        let cached = await manager.loadMetadataFromCache(url: url)
        let parserInvocationCount = await parser.invocationCount()

        XCTAssertEqual(parserInvocationCount, 1)
        XCTAssertEqual(firstResult?.title, "Canonical")
        XCTAssertEqual(secondResult?.title, "Canonical")
        XCTAssertEqual(cached?.title, "Canonical")
    }

    /// Сто конкурентных consumer-ов одного URL присоединяются к одному parser operation до появления cache hit.
    func testOneHundredConcurrentRequestsForSameURLShareSingleParserOperation() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser)
        let url = makeURL("one-hundred-consumers")
        let expected = makeMetadata(title: "Canonical")
        let loads = (0..<100).map { _ in
            Task { await manager.loadMetadata(for: url) }
        }

        await parser.waitForInvocationCount(1)
        await parser.completeNext(for: url, with: expected)

        var results: [TrackMetadataCacheManager.CachedMetadata?] = []
        for load in loads {
            results.append(await load.value)
        }
        let parserInvocationCount = await parser.invocationCount()

        XCTAssertEqual(parserInvocationCount, 1)
        XCTAssertEqual(results.compactMap { $0 }.count, 100)
    }

    func testDifferentURLsRunInParallelOnlyUpToConfiguredLimit() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser, maximumConcurrentLoads: 2)
        let firstURL = makeURL("parallel-first")
        let secondURL = makeURL("parallel-second")
        let thirdURL = makeURL("parallel-third")

        let first = Task { await manager.loadMetadata(for: firstURL) }
        let second = Task { await manager.loadMetadata(for: secondURL) }
        await parser.waitForInvocationCount(2)

        let third = Task { await manager.loadMetadata(for: thirdURL) }
        await Task.yield()
        let initialInvocationCount = await parser.invocationCount()
        let initialMaximumRunningCount = await parser.maximumRunningCount()

        XCTAssertEqual(initialInvocationCount, 2)
        XCTAssertEqual(initialMaximumRunningCount, 2)

        await parser.completeNext(for: firstURL, with: makeMetadata(title: "First"))
        await parser.waitForInvocationCount(3)
        await parser.completeNext(for: secondURL, with: makeMetadata(title: "Second"))
        await parser.completeNext(for: thirdURL, with: makeMetadata(title: "Third"))

        _ = await first.value
        _ = await second.value
        _ = await third.value
        let maximumRunningCount = await parser.maximumRunningCount()

        XCTAssertEqual(maximumRunningCount, 2)
    }

    /// Триста разных URL не обходят actor-owned ограничитель raw metadata parser-а.
    func testThreeHundredDifferentURLsKeepParserConcurrencyWithinConfiguredLimit() async {
        let limit = 6
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser, maximumConcurrentLoads: limit)
        let urls = (0..<300).map { makeURL("distinct-\($0)") }
        let loads = urls.map { url in
            Task { await manager.loadMetadata(for: url) }
        }

        await parser.waitForInvocationCount(limit)
        let initialMaximumRunningCount = await parser.maximumRunningCount()
        XCTAssertEqual(initialMaximumRunningCount, limit)

        for completedCount in urls.indices {
            let startedURLs = await parser.invocationURLs()
            await parser.completeNext(
                for: startedURLs[completedCount],
                with: makeMetadata(title: "Metadata \(completedCount)")
            )

            if completedCount + limit < urls.count {
                await parser.waitForInvocationCount(completedCount + limit + 1)
            }
        }

        var results: [TrackMetadataCacheManager.CachedMetadata?] = []
        for load in loads {
            results.append(await load.value)
        }
        let maximumRunningCount = await parser.maximumRunningCount()

        XCTAssertEqual(results.compactMap { $0 }.count, urls.count)
        XCTAssertEqual(maximumRunningCount, limit)
    }

    func testInvalidatingURLRejectsLateResultAndKeepsNewOperation() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser)
        let url = makeURL("invalidate-url")

        let stale = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(1)

        await manager.invalidate(url: url)

        let current = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(2)

        await parser.completeNext(for: url, with: makeMetadata(title: "Stale"))
        await parser.completeNext(for: url, with: makeMetadata(title: "Current"))

        let staleResult = await stale.value
        let currentResult = await current.value
        let cached = await manager.loadMetadataFromCache(url: url)

        XCTAssertNil(staleResult)
        XCTAssertEqual(currentResult?.title, "Current")
        XCTAssertEqual(cached?.title, "Current")
    }

    func testInvalidateAllRejectsAllLateResultsAndAllowsNewLoads() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser, maximumConcurrentLoads: 2)
        let firstURL = makeURL("invalidate-all-first")
        let secondURL = makeURL("invalidate-all-second")

        let staleFirst = Task { await manager.loadMetadata(for: firstURL) }
        let staleSecond = Task { await manager.loadMetadata(for: secondURL) }
        await parser.waitForInvocationCount(2)

        await manager.invalidateAll()
        await parser.completeNext(for: firstURL, with: makeMetadata(title: "Stale first"))
        await parser.completeNext(for: secondURL, with: makeMetadata(title: "Stale second"))
        let staleFirstResult = await staleFirst.value
        let staleSecondResult = await staleSecond.value
        let staleCachedFirst = await manager.loadMetadataFromCache(url: firstURL)
        let staleCachedSecond = await manager.loadMetadataFromCache(url: secondURL)

        XCTAssertNil(staleFirstResult)
        XCTAssertNil(staleSecondResult)
        XCTAssertNil(staleCachedFirst)
        XCTAssertNil(staleCachedSecond)

        let currentFirst = Task { await manager.loadMetadata(for: firstURL) }
        let currentSecond = Task { await manager.loadMetadata(for: secondURL) }
        await parser.waitForInvocationCount(4)

        await parser.completeNext(for: firstURL, with: makeMetadata(title: "Current first"))
        await parser.completeNext(for: secondURL, with: makeMetadata(title: "Current second"))
        let currentFirstResult = await currentFirst.value
        let currentSecondResult = await currentSecond.value

        XCTAssertEqual(currentFirstResult?.title, "Current first")
        XCTAssertEqual(currentSecondResult?.title, "Current second")
    }

    func testCancelledWaitingOperationDoesNotReceiveSlotAndNextLiveOperationStarts() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser, maximumConcurrentLoads: 2)
        let firstURL = makeURL("wait-first")
        let secondURL = makeURL("wait-second")
        let cancelledURL = makeURL("wait-cancelled")
        let liveURL = makeURL("wait-live")

        let first = Task { await manager.loadMetadata(for: firstURL) }
        let second = Task { await manager.loadMetadata(for: secondURL) }
        await parser.waitForInvocationCount(2)

        let cancelled = Task { await manager.loadMetadata(for: cancelledURL) }
        await Task.yield()
        cancelled.cancel()
        // Task.yield не гарантирует, что actor-владелец уже обработал cancellation handler.
        // Ожидание value фиксирует завершённую отмену consumer до освобождения slot лимитера.
        let cancelledResult = await cancelled.value
        XCTAssertNil(cancelledResult)

        let live = Task { await manager.loadMetadata(for: liveURL) }
        await Task.yield()

        await parser.completeNext(for: firstURL, with: makeMetadata(title: "First"))
        await parser.waitForInvocationCount(3)
        let startedURLs = await parser.invocationURLs()

        // Два независимых Task могут занять исходные slots в разном порядке.
        // Существенно, что отменённый URL не запустился, а live получил следующий slot.
        XCTAssertEqual(Set(startedURLs.prefix(2)), Set([firstURL, secondURL]))
        XCTAssertEqual(startedURLs.last, liveURL)

        await parser.completeNext(for: secondURL, with: makeMetadata(title: "Second"))
        await parser.completeNext(for: liveURL, with: makeMetadata(title: "Live"))
        let liveResult = await live.value

        XCTAssertEqual(liveResult?.title, "Live")
        _ = await first.value
        _ = await second.value
    }

    func testInvalidationCompletesAfterCacheGenerationAndRevisionChange() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser)
        let url = makeURL("revision")

        let first = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(1)

        await manager.invalidate(url: url)
        let cacheAfterURLInvalidation = await manager.loadMetadataFromCache(url: url)

        XCTAssertEqual(manager.revision, 1)
        XCTAssertNil(cacheAfterURLInvalidation)

        await parser.completeNext(for: url, with: makeMetadata(title: "Stale"))
        let firstResult = await first.value
        let cacheAfterStaleCompletion = await manager.loadMetadataFromCache(url: url)
        XCTAssertNil(firstResult)
        XCTAssertNil(cacheAfterStaleCompletion)

        let second = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(2)

        await manager.invalidateAll()
        let cacheAfterFullInvalidation = await manager.loadMetadataFromCache(url: url)

        XCTAssertEqual(manager.revision, 2)
        XCTAssertNil(cacheAfterFullInvalidation)

        await parser.completeNext(for: url, with: makeMetadata(title: "Stale all"))
        let secondResult = await second.value
        XCTAssertNil(secondResult)
    }

    func testCacheHitDoesNotStartParserAgain() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser)
        let url = makeURL("cache-hit")

        let first = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(1)
        await parser.completeNext(for: url, with: makeMetadata(title: "Cached"))
        let firstResult = await first.value
        let cachedResult = await manager.loadMetadata(for: url)
        let parserInvocationCount = await parser.invocationCount()

        XCTAssertEqual(firstResult?.title, "Cached")
        XCTAssertEqual(cachedResult?.title, "Cached")
        XCTAssertEqual(parserInvocationCount, 1)
    }

    func testCanonicalCachedMetadataAlwaysRetainsArtworkReturnedByParser() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser)
        let url = makeURL("artwork")
        let artworkData = Data([0x01, 0x02, 0x03])
        let expected = makeMetadata(title: "Artwork", artworkData: artworkData)

        let load = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(1)
        await parser.completeNext(for: url, with: expected)

        let result = await load.value
        let cached = await manager.loadMetadataFromCache(url: url)

        XCTAssertEqual(result?.artworkData, artworkData)
        XCTAssertEqual(cached?.artworkData, artworkData)
        XCTAssertEqual(cached?.artworkSourceIdentifier, .embeddedArtwork(data: artworkData))
    }

    func testFailedParserDoesNotLeaveZombieInFlightOperation() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser)
        let url = makeURL("failure")

        let failedLoad = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(1)
        await parser.completeNext(for: url, with: nil)
        let failedResult = await failedLoad.value

        XCTAssertNil(failedResult)

        let retry = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(2)
        await parser.completeNext(for: url, with: makeMetadata(title: "Retry"))
        let retryResult = await retry.value
        let parserInvocationCount = await parser.invocationCount()

        XCTAssertEqual(retryResult?.title, "Retry")
        XCTAssertEqual(parserInvocationCount, 2)
    }

    func testCancellingOneConsumerDoesNotBreakSharedResultForAnotherConsumer() async {
        let parser = ControlledMetadataParser()
        let manager = makeManager(parser: parser)
        let url = makeURL("consumer-cancellation")

        let firstConsumer = Task { await manager.loadMetadata(for: url) }
        await parser.waitForInvocationCount(1)

        let secondConsumer = Task { await manager.loadMetadata(for: url) }
        await Task.yield()
        firstConsumer.cancel()

        await parser.completeNext(for: url, with: makeMetadata(title: "Shared"))

        let secondResult = await secondConsumer.value
        let parserInvocationCount = await parser.invocationCount()

        XCTAssertEqual(secondResult?.title, "Shared")
        XCTAssertEqual(parserInvocationCount, 1)
        _ = await firstConsumer.value
    }

    private func makeManager(
        parser: ControlledMetadataParser,
        maximumConcurrentLoads: Int = MetadataCacheStorage.defaultMaximumConcurrentLoads
    ) -> TrackMetadataCacheManager {
        TrackMetadataCacheManager(
            metadataParser: { url in
                await parser.parse(url)
            },
            maximumConcurrentLoads: maximumConcurrentLoads
        )
    }

    private func makeURL(_ name: String) -> URL {
        URL(fileURLWithPath: "/metadata-cache-tests/\(name).flac")
    }

    private func makeMetadata(
        title: String,
        artworkData: Data? = nil
    ) -> TrackMetadataCacheManager.CachedMetadata {
        TrackMetadataCacheManager.CachedMetadata(
            title: title,
            artist: "Artist",
            duration: 120,
            artworkData: artworkData,
            artworkSourceIdentifier: artworkData.map {
                .embeddedArtwork(data: $0)
            }
        )
    }
}

private actor ControlledMetadataParser {
    private struct PendingParse {
        let url: URL
        let continuation: CheckedContinuation<TrackMetadataCacheManager.CachedMetadata?, Never>
    }

    private struct InvocationWaiter {
        let requiredCount: Int
        let continuation: CheckedContinuation<Void, Never>
    }

    private var pendingParses: [UUID: PendingParse] = [:]
    private var pendingIDsByURL: [URL: [UUID]] = [:]
    private var startedURLs: [URL] = []
    private var invocationWaiters: [InvocationWaiter] = []
    private var runningCount = 0
    private var highestRunningCount = 0

    /// Удерживает parser до явного completeNext, чтобы тесты задавали порядок completion без ожиданий по времени.
    func parse(_ url: URL) async -> TrackMetadataCacheManager.CachedMetadata? {
        let id = UUID()

        return await withCheckedContinuation { continuation in
            startedURLs.append(url)
            runningCount += 1
            highestRunningCount = max(highestRunningCount, runningCount)
            pendingParses[id] = PendingParse(url: url, continuation: continuation)
            pendingIDsByURL[url, default: []].append(id)
            resumeInvocationWaitersIfNeeded()
        }
    }

    func waitForInvocationCount(_ requiredCount: Int) async {
        guard startedURLs.count < requiredCount else {
            return
        }

        await withCheckedContinuation { continuation in
            invocationWaiters.append(
                InvocationWaiter(
                    requiredCount: requiredCount,
                    continuation: continuation
                )
            )
        }
    }

    func completeNext(
        for url: URL,
        with metadata: TrackMetadataCacheManager.CachedMetadata?
    ) {
        guard var ids = pendingIDsByURL[url],
              let id = ids.first,
              let pendingParse = pendingParses.removeValue(forKey: id) else {
            XCTFail("Не найден удержанный parser для \(url.path)")
            return
        }

        ids.removeFirst()
        pendingIDsByURL[url] = ids.isEmpty ? nil : ids
        runningCount -= 1
        pendingParse.continuation.resume(returning: metadata)
    }

    func invocationCount() -> Int {
        startedURLs.count
    }

    func invocationURLs() -> [URL] {
        startedURLs
    }

    func maximumRunningCount() -> Int {
        highestRunningCount
    }

    private func resumeInvocationWaitersIfNeeded() {
        var remainingWaiters: [InvocationWaiter] = []

        for waiter in invocationWaiters {
            if startedURLs.count >= waiter.requiredCount {
                waiter.continuation.resume()
            } else {
                remainingWaiters.append(waiter)
            }
        }

        invocationWaiters = remainingWaiters
    }
}

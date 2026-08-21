//
//  PlayerManagerRequestOwnershipTests.swift
//  TrackList
//
//  Проверки ownership асинхронных playback-запросов PlayerManager.
//
//  Created by Pavel Fomin on 20.08.2026.
//

import AVFoundation
import CoreGraphics
import Foundation
// MediaPlayer вызывает callback обложки на собственной очереди, что проверяется ниже.
@preconcurrency import MediaPlayer
import XCTest
@testable import TrackList

@MainActor
final class PlayerManagerRequestOwnershipTests: XCTestCase {

    /// Поздний request освобождает только открытый им scope и не заменяет item более нового playback.
    func testSupersededRequestReleasesOnlyOwnSecurityScope() async throws {
        let runtime = PlayerRuntimeSpy()
        let resourceResolver = PlayerResourceResolverSpy()
        let assetLoader = PlayerAssetLoaderSpy()
        let securityScope = PlayerSecurityScopeSpy()
        let manager = makeManager(
            runtime: runtime,
            resourceResolver: resourceResolver,
            assetLoader: assetLoader,
            securityScope: securityScope
        )
        let first = makeTrack(fileName: "First.m4a")
        let second = makeTrack(fileName: "Second.m4a")
        let firstURL = makeURL(named: "First.m4a")
        let secondURL = makeURL(named: "Second.m4a")
        resourceResolver.setResource(firstURL, for: first.trackId, needsSecurityScope: true)
        resourceResolver.setResource(secondURL, for: second.trackId, needsSecurityScope: true)
        assetLoader.delayIsPlayable(for: firstURL)

        let firstRequestID = manager.beginPlaybackRequest()
        let firstTask = Task { @MainActor in
            try await manager.play(
                requestID: firstRequestID,
                track: first,
                onPreparedLocalFile: { _ in }
            )
        }
        await waitUntil { assetLoader.hasPendingIsPlayable(for: firstURL) }

        let secondRequestID = manager.beginPlaybackRequest()
        let secondResult = try await manager.play(
            requestID: secondRequestID,
            track: second,
            onPreparedLocalFile: { _ in }
        )
        assetLoader.completeIsPlayable(for: firstURL)
        let firstResult = try await firstTask.value

        XCTAssertEqual(secondResult, .started)
        XCTAssertEqual(firstResult, .superseded)
        XCTAssertEqual(manager.currentTrackId, second.trackId)
        XCTAssertEqual(runtime.currentItem, manager.currentPlaybackItem)
        XCTAssertEqual(securityScope.startedURLs, [firstURL, secondURL])
        XCTAssertEqual(securityScope.stoppedURLs, [firstURL])
    }

    /// Уведомление старого AVPlayerItem не должно менять playback-state или инициировать переход в ViewModel.
    func testOldItemFinishIsIgnored() async throws {
        let notificationCenter = NotificationCenter()
        let runtime = PlayerRuntimeSpy()
        let manager = makeManager(runtime: runtime, notificationCenter: notificationCenter)
        let track = makeTrack(fileName: "Current.m4a")
        let requestID = manager.beginPlaybackRequest()
        _ = try await manager.play(requestID: requestID, track: track, onPreparedLocalFile: { _ in })
        let oldItem = AVPlayerItem(url: makeURL(named: "Old.m4a"))
        let finishEvents = PlayerNotificationEventRecorder()
        let token = notificationCenter.addObserver(
            forName: .trackDidFinish,
            object: nil,
            queue: nil
        ) { @Sendable _ in
            Task {
                await finishEvents.recordFinishEvent()
            }
        }
        defer { notificationCenter.removeObserver(token) }

        manager.handlePlayerItemDidFinish(
            Notification(name: .AVPlayerItemDidPlayToEndTime, object: oldItem)
        )

        XCTAssertTrue(manager.isPlaying)
        let finishEventCount = await finishEvents.finishEventCount()
        XCTAssertEqual(finishEventCount, 0)
    }

    /// Уведомление текущего AVPlayerItem доставляется ровно один раз и переводит manager в paused state.
    func testCurrentItemFinishIsHandledOnce() async throws {
        let notificationCenter = NotificationCenter()
        let runtime = PlayerRuntimeSpy()
        let manager = makeManager(runtime: runtime, notificationCenter: notificationCenter)
        let track = makeTrack(fileName: "Current.m4a")
        let requestID = manager.beginPlaybackRequest()
        _ = try await manager.play(requestID: requestID, track: track, onPreparedLocalFile: { _ in })
        let finishEvents = PlayerNotificationEventRecorder()
        let token = notificationCenter.addObserver(
            forName: .trackDidFinish,
            object: nil,
            queue: nil
        ) { @Sendable _ in
            Task {
                await finishEvents.recordFinishEvent()
            }
        }
        defer { notificationCenter.removeObserver(token) }

        manager.handlePlayerItemDidFinish(
            Notification(name: .AVPlayerItemDidPlayToEndTime, object: manager.currentPlaybackItem)
        )

        XCTAssertFalse(manager.isPlaying)
        await waitForFinishEventCount(1, recorder: finishEvents)
    }

    /// Completion старого restart seek не возобновляет уже заменённый AVPlayerItem и не публикует его progress.
    func testStaleRestartSeekAndProgressCallbacksAreIgnored() async throws {
        let runtime = PlayerRuntimeSpy()
        let manager = makeManager(runtime: runtime)
        let first = makeTrack(fileName: "First.m4a")
        let second = makeTrack(fileName: "Second.m4a")
        let firstRequestID = manager.beginPlaybackRequest()
        _ = try await manager.play(requestID: firstRequestID, track: first, onPreparedLocalFile: { _ in })
        manager.restartCurrent()
        var progressCalls = 0
        manager.observeProgress { _ in
            progressCalls += 1
        }

        let secondRequestID = manager.beginPlaybackRequest()
        _ = try await manager.play(requestID: secondRequestID, track: second, onPreparedLocalFile: { _ in })
        runtime.completeLastSeek(didFinish: true)
        runtime.publishProgress(42)
        await Task.yield()

        XCTAssertEqual(runtime.playCallsCount, 2)
        XCTAssertEqual(progressCalls, 0)
        XCTAssertEqual(manager.currentTrackId, second.trackId)
    }

    /// Нормальный lifecycle сохраняет play, pause, playCurrent, seek, progress, duration и purchased-source без security scope.
    func testNormalPlaybackControlsAndPurchasedResourceRemainAvailable() async throws {
        let runtime = PlayerRuntimeSpy()
        let resourceResolver = PlayerResourceResolverSpy()
        let assetLoader = PlayerAssetLoaderSpy(duration: 180)
        let securityScope = PlayerSecurityScopeSpy()
        let notificationCenter = NotificationCenter()
        let manager = makeManager(
            runtime: runtime,
            resourceResolver: resourceResolver,
            assetLoader: assetLoader,
            securityScope: securityScope,
            notificationCenter: notificationCenter
        )
        let track = makeTrack(fileName: "Purchased.m4a")
        let purchasedURL = makeURL(named: "Purchased.m4a")
        resourceResolver.setResource(purchasedURL, for: track.trackId, needsSecurityScope: false)
        let receivedDuration = PlayerNotificationEventRecorder()
        let durationToken = notificationCenter.addObserver(
            forName: .trackDurationUpdated,
            object: nil,
            queue: nil
        ) { @Sendable notification in
            let duration = notification.userInfo?["duration"] as? TimeInterval
            Task {
                await receivedDuration.recordDuration(duration)
            }
        }
        defer { notificationCenter.removeObserver(durationToken) }

        let requestID = manager.beginPlaybackRequest()
        let result = try await manager.play(requestID: requestID, track: track, onPreparedLocalFile: { _ in })
        var receivedProgress: TimeInterval?
        manager.observeProgress { receivedProgress = $0 }
        runtime.publishProgress(12.5)
        manager.pause()
        manager.playCurrent()
        manager.seek(to: 45)

        XCTAssertEqual(result, .started)
        await waitForDuration(recorder: receivedDuration)
        let observedDuration = await receivedDuration.duration()
        XCTAssertEqual(observedDuration, 180)
        XCTAssertEqual(receivedProgress, 12.5)
        XCTAssertTrue(manager.isPlaying)
        XCTAssertEqual(runtime.lastSeekTime?.seconds ?? -1, 45, accuracy: 0.000_1)
        XCTAssertTrue(securityScope.startedURLs.isEmpty)
    }

    /// Callback обложки не наследует MainActor и безопасно вызывается системной очередью MediaPlayer.
    func testNowPlayingArtworkCallbackCanRunOnSystemQueue() async throws {
        let manager = makeManager(runtime: PlayerRuntimeSpy())
        let nowPlayingCenter = MPNowPlayingInfoCenter.default()
        let previousInfo = nowPlayingCenter.nowPlayingInfo
        defer { nowPlayingCenter.nowPlayingInfo = previousInfo }

        manager.applyNowPlaying(
            snapshot: NowPlayingSnapshot(
                title: "Title",
                artist: "Artist",
                album: "Album",
                artwork: makeArtwork(),
                currentTime: 0,
                duration: 180,
                isPlaying: true
            )
        )

        let artwork = try XCTUnwrap(
            nowPlayingCenter.nowPlayingInfo?[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork
        )

        // Detached task намеренно моделирует очередь MediaPlayer, не связанную с MainActor.
        let imageWasCreated = await Task.detached { @Sendable in
            artwork.image(at: CGSize(width: 1, height: 1)) != nil
        }.value

        XCTAssertTrue(imageWasCreated)
    }

    /// Собирает PlayerManager с контролируемыми runtime зависимостями без реального AVPlayer и файловой системы.
    private func makeManager(
        runtime: PlayerRuntimeSpy,
        resourceResolver: PlayerResourceResolverSpy? = nil,
        assetLoader: PlayerAssetLoaderSpy? = nil,
        securityScope: PlayerSecurityScopeSpy? = nil,
        notificationCenter: NotificationCenter = .default
    ) -> PlayerManager {
        let resolvedResourceResolver = resourceResolver ?? PlayerResourceResolverSpy()
        let resolvedAssetLoader = assetLoader ?? PlayerAssetLoaderSpy()
        let resolvedSecurityScope = securityScope ?? PlayerSecurityScopeSpy()
        return PlayerManager(
            player: runtime,
            playbackResourceResolver: resolvedResourceResolver,
            assetLoader: resolvedAssetLoader,
            securityScopedResourceAccessor: resolvedSecurityScope,
            notificationCenter: notificationCenter
        )
    }

    /// Создаёт iTunes-style display model, исключающую BookmarkResolver из unit-теста.
    private func makeTrack(fileName: String) -> PlayerTrack {
        PlayerTrack(
            trackId: UUID(),
            title: fileName,
            artist: "Artist",
            duration: 180,
            fileName: fileName,
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: makeURL(named: fileName)
        )
    }

    /// Формирует уникальный URL, который используется только как identity AVPlayerItem в controlled fake.
    private func makeURL(named fileName: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "PlayerManagerRequestOwnershipTests-\(UUID().uuidString)-\(fileName)"
        )
    }

    /// Создаёт минимальное валидное изображение без зависимости от файловой системы или UIKit runtime.
    private func makeArtwork() -> CGImage {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    /// Ожидает только контролируемую continuation без временной задержки устройства.
    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<100 {
            if condition() {
                return
            }
            await Task.yield()
        }

        XCTFail("Не достигнуто контролируемое состояние PlayerManager")
    }

    /// Ожидает доставку NotificationCenter callback через actor, не разделяя mutable XCTest state с @Sendable closure.
    private func waitForFinishEventCount(
        _ expectedCount: Int,
        recorder: PlayerNotificationEventRecorder
    ) async {
        for _ in 0..<100 {
            if await recorder.finishEventCount() == expectedCount {
                return
            }
            await Task.yield()
        }

        XCTFail("Не доставлено ожидаемое число событий завершения плеера")
    }

    /// Ожидает immutable значение duration, зафиксированное callback-ом внешнего NotificationCenter.
    private func waitForDuration(
        recorder: PlayerNotificationEventRecorder
    ) async {
        for _ in 0..<100 {
            if await recorder.duration() != nil {
                return
            }
            await Task.yield()
        }

        XCTFail("Не доставлена длительность трека")
    }
}

/// Actor владеет mutable test-state, который внешний @Sendable notification callback не может менять напрямую.
private actor PlayerNotificationEventRecorder {
    private var finishedEvents = 0
    private var receivedDuration: TimeInterval?

    func recordFinishEvent() {
        finishedEvents += 1
    }

    func finishEventCount() -> Int {
        finishedEvents
    }

    func recordDuration(_ duration: TimeInterval?) {
        receivedDuration = duration
    }

    func duration() -> TimeInterval? {
        receivedDuration
    }
}

/// Хранит item и callbacks AVPlayer, чтобы тест мог явно завершить seek и progress старого lifecycle.
@MainActor
private final class PlayerRuntimeSpy: PlayerRuntimeControlling {
    private(set) var currentItem: AVPlayerItem?
    private(set) var playCallsCount = 0
    private(set) var lastSeekTime: CMTime?
    private var restartSeekCompletion: ((Bool) -> Void)?
    private var progressUpdate: ((CMTime) -> Void)?

    func replaceCurrentItem(with item: AVPlayerItem?) {
        currentItem = item
    }

    func play() {
        playCallsCount += 1
    }

    func pause() {}

    func seek(
        to time: CMTime,
        toleranceBefore: CMTime,
        toleranceAfter: CMTime,
        completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        lastSeekTime = time
        restartSeekCompletion = completionHandler
    }

    func seek(to time: CMTime) {
        lastSeekTime = time
    }

    func addPeriodicTimeObserver(
        forInterval interval: CMTime,
        queue: DispatchQueue,
        using block: @escaping @Sendable (CMTime) -> Void
    ) -> Any {
        progressUpdate = block
        return UUID()
    }

    func removeTimeObserver(_: Any) {
        progressUpdate = nil
    }

    /// Явно завершает сохранённый restart seek после того, как тест заменил current item.
    func completeLastSeek(didFinish: Bool) {
        restartSeekCompletion?(didFinish)
        restartSeekCompletion = nil
    }

    /// Передаёт progress через тот же callback, который использует production observer.
    func publishProgress(_ seconds: TimeInterval) {
        progressUpdate?(CMTime(seconds: seconds, preferredTimescale: 600))
    }
}

/// Возвращает тестовый playback resource и не обращается к BookmarkResolver.
@MainActor
private final class PlayerResourceResolverSpy: PlayerPlaybackResourceResolving {
    private var resources: [UUID: PlayerPlaybackResource] = [:]

    func setResource(_ url: URL, for trackID: UUID, needsSecurityScope: Bool) {
        resources[trackID] = PlayerPlaybackResource(
            url: url,
            needsSecurityScopedAccess: needsSecurityScope
        )
    }

    func resolvePlaybackResource(
        for track: any TrackDisplayable
    ) async throws -> PlayerPlaybackResource {
        if let resource = resources[track.trackId] {
            return resource
        }

        guard let playerTrack = track as? PlayerTrack,
              let assetURL = playerTrack.assetURL
        else {
            throw PlayerRequestOwnershipTestError.missingResource
        }

        return PlayerPlaybackResource(url: assetURL, needsSecurityScopedAccess: false)
    }
}

/// Удерживает только заданную проверку isPlayable, чтобы тест воспроизводил late completion без sleep.
@MainActor
private final class PlayerAssetLoaderSpy: PlayerAssetLoading {
    private let duration: TimeInterval
    private var delayedURLs: Set<URL> = []
    private var continuations: [URL: CheckedContinuation<Void, Error>] = [:]

    init(duration: TimeInterval = 120) {
        self.duration = duration
    }

    func delayIsPlayable(for url: URL) {
        delayedURLs.insert(url)
    }

    func hasPendingIsPlayable(for url: URL) -> Bool {
        continuations[url] != nil
    }

    func loadIsPlayable(for item: AVPlayerItem) async throws {
        guard let url = (item.asset as? AVURLAsset)?.url,
              delayedURLs.contains(url)
        else {
            return
        }

        try await withCheckedThrowingContinuation { continuation in
            continuations[url] = continuation
        }
    }

    func loadDuration(for _: AVPlayerItem) async -> TimeInterval {
        duration
    }

    /// Возобновляет только явно удерживаемую asset-проверку старого request.
    func completeIsPlayable(for url: URL) {
        continuations.removeValue(forKey: url)?.resume()
    }
}

/// Фиксирует start/stop парность security scope без вызова системного URL API.
@MainActor
private final class PlayerSecurityScopeSpy: PlayerSecurityScopedResourceAccessing {
    private(set) var startedURLs: [URL] = []
    private(set) var stoppedURLs: [URL] = []

    func startAccessing(_ url: URL) -> Bool {
        startedURLs.append(url)
        return true
    }

    func stopAccessing(_ url: URL) {
        stoppedURLs.append(url)
    }
}

/// Описывает только ошибку некорректной изолированной настройки теста.
private enum PlayerRequestOwnershipTestError: Error {
    case missingResource
}

//
//  PlayerViewModelWaveformTests.swift
//  TrackList
//
//  Проверки состояния waveform в PlayerViewModel без декодирования аудиофайлов.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation
import XCTest
@testable import TrackList

@MainActor
final class PlayerViewModelWaveformTests: XCTestCase {

    /// Временные каталоги нужны только проверке общего пути файлового кэша.
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for directoryURL in temporaryDirectories {
            try? FileManager.default.removeItem(at: directoryURL)
        }
        temporaryDirectories = []
    }

    /// Выбор нового трека запускает ровно один запрос с фиксированным размером waveform.
    func testSelectingNewTrackRequestsWaveformOnceAndPublishesReadyState() async {
        let generator = ImmediateWaveformGenerator(samples: makeSamples(value: 0.4))
        let harness = makeHarness(waveformGenerator: generator)
        let track = makeTrack(fileName: "First.m4a")
        let fileURL = makeFileURL(named: "First.m4a")
        harness.playerManager.setPreparedURL(fileURL, for: track.trackId)

        harness.viewModel.play(track: track)

        await waitForWaveformState(
            .ready(makeSamples(value: 0.4)),
            in: harness.viewModel
        )

        let requestsCount = await generator.requestsCount
        let requestedSampleCounts = await generator.requestedSampleCounts
        XCTAssertEqual(requestsCount, 1)
        XCTAssertEqual(
            requestedSampleCounts,
            [PlayerWaveformConfiguration.miniPlayerSampleCount]
        )
    }

    /// Подготовленный файл запускает waveform до завершения ожидания duration в PlayerManager.
    func testPreparedLocalFileStartsWaveformBeforePlayerPlayCompletes() async {
        let samples = makeSamples(value: 0.4)
        let generator = ImmediateWaveformGenerator(samples: samples)
        let harness = makeHarness(waveformGenerator: generator)
        let track = makeTrack(fileName: "Early.m4a")
        let fileURL = makeFileURL(named: "Early.m4a")
        harness.playerManager.setPreparedURL(fileURL, for: track.trackId)
        harness.playerManager.delaysPlayCompletion = true

        harness.viewModel.play(track: track)
        await waitForWaveformState(.ready(samples), in: harness.viewModel)

        XCTAssertTrue(harness.playerManager.isWaitingForPlayCompletion)
        XCTAssertFalse(harness.viewModel.isPlaying)

        harness.playerManager.completePlay()
        await waitForPlaybackStart(in: harness.viewModel)
    }

    /// Обновление времени и play/pause управляют playback, но не создают новый файловый запрос.
    func testProgressAndPlayPauseDoNotRestartWaveformGeneration() async {
        let generator = ImmediateWaveformGenerator(samples: makeSamples(value: 0.2))
        let harness = makeHarness(waveformGenerator: generator)
        let track = makeTrack(fileName: "Progress.m4a")
        let fileURL = makeFileURL(named: "Progress.m4a")
        harness.playerManager.setPreparedURL(fileURL, for: track.trackId)

        harness.viewModel.play(track: track)
        await waitForWaveformState(
            .ready(makeSamples(value: 0.2)),
            in: harness.viewModel
        )

        harness.playerManager.publishProgress(12)
        harness.viewModel.togglePlayPause()
        harness.viewModel.togglePlayPause()
        await Task.yield()

        let requestsCount = await generator.requestsCount
        XCTAssertEqual(requestsCount, 1)
    }

    /// Observer ограничен четырьмя обновлениями в секунду, чтобы progress был плавнее секундного без кадрового таймера.
    func testProgressObserverUsesQuarterSecondInterval() {
        XCTAssertEqual(
            PlayerProgressObservationConfiguration.interval,
            0.25,
            accuracy: 0.000_1
        )
    }

    /// Каждое дробное значение observer сразу доходит до состояния мини-плеера и не запускает новую waveform.
    func testProgressCallbacksPublishEachQuarterSecondWithoutRestartingWaveform() async {
        let generator = ImmediateWaveformGenerator(samples: makeSamples(value: 0.3))
        let harness = makeHarness(waveformGenerator: generator)
        let track = makeTrack(fileName: "QuarterSecond.m4a")
        let fileURL = makeFileURL(named: "QuarterSecond.m4a")
        harness.playerManager.setPreparedURL(fileURL, for: track.trackId)

        harness.viewModel.play(track: track)
        await waitForWaveformState(.ready(makeSamples(value: 0.3)), in: harness.viewModel)
        await waitForPlaybackStart(in: harness.viewModel)

        for expectedTime in [12.0, 12.25, 12.5, 12.75] {
            harness.playerManager.publishProgress(expectedTime)

            XCTAssertEqual(harness.viewModel.currentTime, expectedTime, accuracy: 0.000_1)
            XCTAssertEqual(
                miniPlayerCurrentTime(in: harness.viewModel.miniPlayerState),
                expectedTime,
                accuracy: 0.000_1
            )
        }

        let requestsCount = await generator.requestsCount
        XCTAssertEqual(requestsCount, 1)
    }

    /// Seek, пауза, продолжение и конец трека сохраняют единый путь публикации progress.
    func testSeekPauseResumeAndTrackEndKeepProgressStateConsistent() async {
        let generator = ImmediateWaveformGenerator(samples: makeSamples(value: 0.6))
        let harness = makeHarness(waveformGenerator: generator)
        let track = makeTrack(fileName: "ProgressControls.m4a")
        let fileURL = makeFileURL(named: "ProgressControls.m4a")
        harness.playerManager.setPreparedURL(fileURL, for: track.trackId)

        harness.viewModel.play(track: track)
        await waitForWaveformState(.ready(makeSamples(value: 0.6)), in: harness.viewModel)
        await waitForPlaybackStart(in: harness.viewModel)

        harness.viewModel.seek(to: 72.5)
        XCTAssertEqual(
            harness.playerManager.lastSeekTime ?? -1,
            72.5,
            accuracy: 0.000_1
        )
        XCTAssertEqual(
            miniPlayerCurrentTime(in: harness.viewModel.miniPlayerState),
            72.5,
            accuracy: 0.000_1
        )

        harness.viewModel.togglePlayPause()
        XCTAssertFalse(harness.viewModel.isPlaying)
        harness.viewModel.togglePlayPause()
        XCTAssertTrue(harness.viewModel.isPlaying)

        harness.playerManager.publishProgress(120)
        XCTAssertEqual(
            MiniPlayerWaveformLayout.progress(
                currentTime: miniPlayerCurrentTime(in: harness.viewModel.miniPlayerState),
                duration: 120
            ),
            1
        )
    }

    /// Результат отменённой задачи старого трека не должен попасть в состояние нового трека.
    func testFastTrackChangeDoesNotPublishOldWaveformResult() async {
        let generator = ControllableWaveformGenerator()
        let harness = makeHarness(waveformGenerator: generator)
        let firstTrack = makeTrack(fileName: "First.m4a")
        let secondTrack = makeTrack(fileName: "Second.m4a")
        let firstURL = makeFileURL(named: "First.m4a")
        let secondURL = makeFileURL(named: "Second.m4a")
        let oldSamples = makeSamples(value: 0.1)
        let newSamples = makeSamples(value: 0.9)
        harness.playerManager.setPreparedURL(firstURL, for: firstTrack.trackId)
        harness.playerManager.setPreparedURL(secondURL, for: secondTrack.trackId)

        harness.viewModel.play(track: firstTrack)
        await waitForPendingRequest(for: firstURL, in: generator)

        harness.viewModel.play(track: secondTrack)
        await waitForPendingRequest(for: secondURL, in: generator)
        await generator.completeRequest(for: firstURL, with: oldSamples)
        await Task.yield()

        XCTAssertNotEqual(harness.viewModel.waveformState, .ready(oldSamples))

        await generator.completeRequest(for: secondURL, with: newSamples)
        await waitForWaveformState(.ready(newSamples), in: harness.viewModel)
    }

    /// Смена текущего трека отменяет задачу до того, как начнётся обработка следующего файла.
    func testChangingTrackCancelsPreviousWaveformTask() async {
        let generator = ControllableWaveformGenerator()
        let harness = makeHarness(waveformGenerator: generator)
        let firstTrack = makeTrack(fileName: "First.m4a")
        let secondTrack = makeTrack(fileName: "Second.m4a")
        let firstURL = makeFileURL(named: "First.m4a")
        let secondURL = makeFileURL(named: "Second.m4a")
        harness.playerManager.setPreparedURL(firstURL, for: firstTrack.trackId)
        harness.playerManager.setPreparedURL(secondURL, for: secondTrack.trackId)

        harness.viewModel.play(track: firstTrack)
        await waitForPendingRequest(for: firstURL, in: generator)

        harness.viewModel.play(track: secondTrack)
        await waitForCancellation(of: firstURL, in: generator)

        XCTAssertEqual(harness.viewModel.waveformState, .loading)
    }

    /// Поздний сигнал прежнего PlayerManager не отменяет уже работающую waveform текущего трека.
    func testLatePreparedLocalFileDoesNotCancelCurrentWaveformTask() async {
        let generator = ControllableWaveformGenerator()
        let harness = makeHarness(waveformGenerator: generator)
        let firstTrack = makeTrack(fileName: "Late.m4a")
        let secondTrack = makeTrack(fileName: "Current.m4a")
        let firstURL = makeFileURL(named: "Late.m4a")
        let secondURL = makeFileURL(named: "Current.m4a")
        let secondSamples = makeSamples(value: 0.8)
        harness.playerManager.setPreparedURL(firstURL, for: firstTrack.trackId)
        harness.playerManager.setPreparedURL(secondURL, for: secondTrack.trackId)
        harness.playerManager.delayPreparedLocalFile(for: firstTrack.trackId)

        harness.viewModel.play(track: firstTrack)
        harness.viewModel.play(track: secondTrack)
        await waitForPendingRequest(for: secondURL, in: generator)

        await harness.playerManager.deliverPreparedLocalFile(for: firstTrack.trackId)
        await Task.yield()

        let hasCurrentPendingRequest = await generator.hasPendingRequest(for: secondURL)
        let wasCurrentRequestCancelled = await generator.wasCancelled(secondURL)
        XCTAssertTrue(hasCurrentPendingRequest)
        XCTAssertFalse(wasCurrentRequestCancelled)

        await generator.completeRequest(for: secondURL, with: secondSamples)
        await waitForWaveformState(.ready(secondSamples), in: harness.viewModel)
    }

    /// Ошибка waveform остаётся изолированной от состояния воспроизведения и переводит UI в fallback.
    func testWaveformFailureDoesNotChangePlaybackState() async {
        let generator = ControllableWaveformGenerator()
        let harness = makeHarness(waveformGenerator: generator)
        let track = makeTrack(fileName: "Broken.m4a")
        let fileURL = makeFileURL(named: "Broken.m4a")
        harness.playerManager.setPreparedURL(fileURL, for: track.trackId)

        harness.viewModel.play(track: track)
        await waitForPendingRequest(for: fileURL, in: generator)
        await generator.failRequest(for: fileURL)

        await waitForWaveformState(.failed, in: harness.viewModel)

        XCTAssertTrue(harness.viewModel.isPlaying)
        XCTAssertEqual(harness.viewModel.currentTrackDisplayable?.trackId, track.trackId)
    }

    /// Удаление текущего элемента очереди очищает производные данные вместе с мини-плеером.
    func testRemovingCurrentTrackMakesWaveformUnavailable() async {
        let generator = ImmediateWaveformGenerator(samples: makeSamples(value: 0.5))
        let harness = makeHarness(waveformGenerator: generator)
        let track = makeTrack(fileName: "Deleted.m4a")
        let fileURL = makeFileURL(named: "Deleted.m4a")
        harness.playerManager.setPreparedURL(fileURL, for: track.trackId)
        harness.playlistManager.tracks = [track]

        harness.viewModel.play(track: track)
        await waitForWaveformState(
            .ready(makeSamples(value: 0.5)),
            in: harness.viewModel
        )

        XCTAssertTrue(harness.playlistManager.clear())

        XCTAssertEqual(harness.viewModel.waveformState, .unavailable)
        XCTAssertNil(harness.viewModel.currentTrackDisplayable)
    }

    /// Кэшированный waveform возвращается ViewModel тем же контрактом без повторного декодирования.
    func testCachedGeneratorPublishesCachedSamplesThroughSameViewModelState() async throws {
        let directoryURL = try makeTemporaryDirectory(named: "PlayerViewModelWaveformCache")
        let fileURL = try WaveformTestFileFactory.makeRegularFile(
            in: directoryURL,
            named: "shared.m4a",
            contents: Data([0x01, 0x02, 0x03])
        )
        let decodedSamples = makeSamples(value: 0.7)
        let rawGenerator = ImmediateWaveformGenerator(samples: decodedSamples)
        let cachedGenerator = WaveformCachedGenerator(
            generator: rawGenerator,
            cache: WaveformFileCache(
                directoryURL: directoryURL.appendingPathComponent("Cache", isDirectory: true)
            )
        )
        let harness = makeHarness(waveformGenerator: cachedGenerator)
        let firstTrack = makeTrack(fileName: "First.m4a")
        let secondTrack = makeTrack(
            fileName: "Second.m4a",
            trackId: firstTrack.trackId
        )
        harness.playerManager.setPreparedURL(fileURL, for: firstTrack.trackId)
        harness.playerManager.setPreparedURL(fileURL, for: secondTrack.trackId)

        harness.viewModel.play(track: firstTrack)
        await waitForWaveformState(.ready(decodedSamples), in: harness.viewModel)

        harness.viewModel.play(track: secondTrack)
        await waitForWaveformState(.ready(decodedSamples), in: harness.viewModel)

        let rawRequestsCount = await rawGenerator.requestsCount
        XCTAssertEqual(rawRequestsCount, 1)
    }

    /// Отсутствие локального URL оставляет явное состояние unavailable и общую заглушку waveform.
    func testUnavailablePreparedFileKeepsWaveformUnavailable() async {
        let generator = ImmediateWaveformGenerator(samples: makeSamples(value: 0.6))
        let harness = makeHarness(waveformGenerator: generator)
        let track = makeTrack(fileName: "Unavailable.m4a")

        harness.viewModel.play(track: track)
        await Task.yield()

        XCTAssertEqual(harness.viewModel.waveformState, .unavailable)
        let requestsCount = await generator.requestsCount
        XCTAssertEqual(requestsCount, 0)
    }

    /// Собирает ViewModel с полностью изолированными зависимостями playback и persistence.
    private func makeHarness(
        waveformGenerator: any WaveformGenerating
    ) -> PlayerViewModelWaveformHarness {
        let playerManager = PlayerManagerSpy()
        let playlistManager = PlaylistManager(
            databaseStore: PlayerQueuePersistenceSpy(),
            loadsInitialQueue: false
        )
        let viewModel = PlayerViewModel(
            playerManager: playerManager,
            playbackContextStore: PlayerPlaybackContextStore(
                playbackModePersistence: PlaybackModePersistenceSpy()
            ),
            eventObserver: PlayerEventObserverSpy(),
            toastPresenter: ToastPresenterSpy(),
            statePersistence: PlayerStatePersistenceSpy(),
            playlistManager: playlistManager,
            waveformGenerator: waveformGenerator
        )

        return PlayerViewModelWaveformHarness(
            viewModel: viewModel,
            playerManager: playerManager,
            playlistManager: playlistManager
        )
    }

    /// Использует iTunes-модель, чтобы изолированные тесты не запускали BookmarkResolver и runtime snapshot.
    private func makeTrack(
        fileName: String,
        trackId: UUID = UUID()
    ) -> PlayerTrack {
        PlayerTrack(
            trackId: trackId,
            title: fileName,
            artist: "Artist",
            duration: 120,
            fileName: fileName,
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: makeFileURL(named: fileName)
        )
    }

    /// Формирует индивидуальный URL, который PlayerManagerSpy выдаёт как уже подготовленный playback-ресурс.
    private func makeFileURL(named fileName: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "PlayerViewModelWaveformTests-\(UUID().uuidString)-\(fileName)",
            isDirectory: false
        )
    }

    /// Возвращает компактный корректный набор амплитуд, равный используемому размеру мини-плеера.
    private func makeSamples(value: Double) -> [Double] {
        Array(repeating: value, count: PlayerWaveformConfiguration.miniPlayerSampleCount)
    }

    /// Извлекает progress из единого состояния мини-плеера без обращения к View.
    private func miniPlayerCurrentTime(in state: MiniPlayerState) -> TimeInterval {
        switch state {
        case let .playing(_, progressState),
             let .paused(_, progressState):
            return progressState.currentTime
        case .empty,
             .loading,
             .error:
            XCTFail("Ожидалось состояние progress мини-плеера")
            return 0
        }
    }

    /// Создаёт тестовый каталог, который будет удалён в tearDown.
    private func makeTemporaryDirectory(named name: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        temporaryDirectories.append(directoryURL)
        return directoryURL
    }

    /// Ожидает публикацию итогового состояния, не полагаясь на задержки устройства.
    private func waitForWaveformState(
        _ expectedState: PlayerWaveformState,
        in viewModel: PlayerViewModel
    ) async {
        for _ in 0..<100 {
            if viewModel.waveformState == expectedState {
                return
            }
            await Task.yield()
        }

        XCTFail("Не опубликовано ожидаемое состояние waveform: \(expectedState)")
    }

    /// Ожидает регистрацию контролируемого запроса до его завершения из теста.
    private func waitForPendingRequest(
        for fileURL: URL,
        in generator: ControllableWaveformGenerator
    ) async {
        for _ in 0..<100 {
            if await generator.hasPendingRequest(for: fileURL) {
                return
            }
            await Task.yield()
        }

        XCTFail("Не зарегистрирован запрос waveform для \(fileURL.lastPathComponent)")
    }

    /// Ожидает подтверждение отмены, которое генератор фиксирует через cancellation handler.
    private func waitForCancellation(
        of fileURL: URL,
        in generator: ControllableWaveformGenerator
    ) async {
        for _ in 0..<100 {
            if await generator.wasCancelled(fileURL) {
                return
            }
            await Task.yield()
        }

        XCTFail("Не зафиксирована отмена waveform для \(fileURL.lastPathComponent)")
    }

    /// Ожидает окончание искусственно задержанного PlayerManager.play без предположений о длительности задержки.
    private func waitForPlaybackStart(in viewModel: PlayerViewModel) async {
        for _ in 0..<100 {
            if viewModel.isPlaying {
                return
            }
            await Task.yield()
        }

        XCTFail("PlayerViewModel не подтвердил завершение playback")
    }
}

/// Связывает изолированные зависимости, чтобы каждый тест не использовал общий singleton.
private struct PlayerViewModelWaveformHarness {
    let viewModel: PlayerViewModel
    let playerManager: PlayerManagerSpy
    let playlistManager: PlaylistManager
}

/// Имитирует подготовленный PlayerManager URL и сохраняет управление playback без AVPlayer.
private final class PlayerManagerSpy: PlayerManaging {
    private var preparedURLs: [UUID: URL] = [:]
    private var currentTrackId: UUID?
    private var progressUpdate: ((TimeInterval) -> Void)?
    private var playCompletionContinuation: CheckedContinuation<Void, Never>?
    private var delayedPreparedTrackIds: Set<UUID> = []
    private var delayedPreparedHandlers: [UUID: PlayerPreparedLocalFileHandler] = [:]

    /// Позволяет тесту удержать завершение PlayerManager.play после выдачи подготовленного URL.
    var delaysPlayCompletion = false
    /// Показывает, что waveform уже может работать, пока основной код ещё ожидает duration.
    var isWaitingForPlayCompletion: Bool {
        playCompletionContinuation != nil
    }
    private(set) var lastSeekTime: TimeInterval?

    func setPreparedURL(_ fileURL: URL, for trackId: UUID) {
        preparedURLs[trackId] = fileURL
    }

    /// Откладывает только сигнал готового файла, чтобы проверить защиту от позднего обратного вызова.
    func delayPreparedLocalFile(for trackId: UUID) {
        delayedPreparedTrackIds.insert(trackId)
    }

    func play(
        track: any TrackDisplayable,
        onPreparedLocalFile: @escaping PlayerPreparedLocalFileHandler
    ) async throws {
        currentTrackId = track.trackId

        if let preparedURL = preparedURLs[track.trackId] {
            if delayedPreparedTrackIds.contains(track.trackId) {
                delayedPreparedHandlers[track.trackId] = onPreparedLocalFile
            } else {
                await onPreparedLocalFile(
                    PlayerPreparedLocalFile(
                        trackId: track.trackId,
                        fileURL: preparedURL
                    )
                )
            }
        }

        guard delaysPlayCompletion else { return }
        await withCheckedContinuation { continuation in
            playCompletionContinuation = continuation
        }
    }

    func playCurrent() {}

    func restartCurrent() {}

    func pause() {}

    func seek(to time: TimeInterval) {
        lastSeekTime = time
    }

    func stopAccessingCurrentTrack() {
        currentTrackId = nil
    }

    func preparedLocalFileURL(for trackId: UUID) -> URL? {
        guard currentTrackId == trackId else { return nil }
        return preparedURLs[trackId]
    }

    func observeProgress(update: @escaping (TimeInterval) -> Void) {
        progressUpdate = update
    }

    func removeTimeObserver() {
        progressUpdate = nil
    }

    func setupRemoteCommandCenter(
        onPlay: @escaping () -> Void,
        onPause: @escaping () -> Void,
        onNext: @escaping () -> Void,
        onPrevious: @escaping () -> Void
    ) {}

    func applyNowPlaying(snapshot: NowPlayingSnapshot) {}

    func applyPlaybackTime(currentTime: TimeInterval, isPlaying: Bool) {}

    /// Завершает искусственное ожидание, которым тест моделирует загрузку duration после контрольной точки.
    func completePlay() {
        playCompletionContinuation?.resume()
        playCompletionContinuation = nil
    }

    /// Доставляет сохранённый сигнал так, как если бы предыдущая подготовка завершилась позднее.
    func deliverPreparedLocalFile(for trackId: UUID) async {
        guard let preparedURL = preparedURLs[trackId],
              let handler = delayedPreparedHandlers.removeValue(forKey: trackId)
        else {
            return
        }

        await handler(
            PlayerPreparedLocalFile(
                trackId: trackId,
                fileURL: preparedURL
            )
        )
    }

    /// Доставляет обновление времени тем же обратным вызовом, которым основной код получает AVPlayer progress.
    func publishProgress(_ time: TimeInterval) {
        progressUpdate?(time)
    }
}

/// Возвращает готовый результат и фиксирует параметры запуска без обращения к файловой системе.
private actor ImmediateWaveformGenerator: WaveformGenerating {
    private let samples: [Double]
    private var requests = 0
    private var sampleCounts: [Int] = []

    init(samples: [Double]) {
        self.samples = samples
    }

    func generateSamples(
        from fileURL: URL,
        sampleCount: Int
    ) async throws -> [Double] {
        requests += 1
        sampleCounts.append(sampleCount)
        return samples
    }

    var requestsCount: Int {
        requests
    }

    var requestedSampleCounts: [Int] {
        sampleCounts
    }
}

/// Удерживает запросы до команды теста и фиксирует отмену без автоматического возврата старого результата.
private actor ControllableWaveformGenerator: WaveformGenerating {
    private var continuations: [URL: CheckedContinuation<[Double], Error>] = [:]
    private var cancelledURLs: Set<URL> = []

    func generateSamples(
        from fileURL: URL,
        sampleCount: Int
    ) async throws -> [Double] {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                continuations[fileURL] = continuation
            }
        } onCancel: {
            Task {
                await self.recordCancellation(for: fileURL)
            }
        }
    }

    func hasPendingRequest(for fileURL: URL) -> Bool {
        continuations[fileURL] != nil
    }

    func wasCancelled(_ fileURL: URL) -> Bool {
        cancelledURLs.contains(fileURL)
    }

    func completeRequest(for fileURL: URL, with samples: [Double]) {
        continuations.removeValue(forKey: fileURL)?.resume(returning: samples)
    }

    func failRequest(for fileURL: URL) {
        continuations.removeValue(forKey: fileURL)?.resume(throwing: WaveformTestError.failed)
    }

    /// Сохраняет факт отмены, но намеренно не завершает continuation: тест проверяет защиту от старого результата.
    private func recordCancellation(for fileURL: URL) {
        cancelledURLs.insert(fileURL)
    }
}

/// Локальная ошибка позволяет проверить fallback без влияния на playback-ошибки приложения.
private enum WaveformTestError: Error {
    case failed
}

/// Изолирует PlayerViewModel от постоянной очереди и не обращается к SQLite.
private final class PlayerQueuePersistenceSpy: PlayerQueuePersisting {
    func fetchQueue() throws -> [PlayerTrack] {
        []
    }

    func replaceQueue(_ tracks: [PlayerTrack]) throws {}
}

/// Сохраняет только данные, которыми ViewModel подтверждает удаление текущего элемента очереди.
private final class PlayerStatePersistenceSpy: PlayerStatePersisting {
    private var state: PlayerStateDatabaseModel?

    func loadState() throws -> PlayerStateDatabaseModel? {
        state
    }

    func saveCurrentTrack(
        trackId: UUID,
        queueItemId: UUID?,
        duration: TimeInterval,
        playbackMode: PlaybackMode,
        contextSource: PlaybackContextSource
    ) throws {
        state = PlayerStateDatabaseModel(
            id: 1,
            currentQueueItemId: queueItemId,
            currentTrackId: trackId,
            contextType: .playerQueue,
            contextId: nil,
            collectionCategory: nil,
            collectionValue: nil,
            collectionArtistKey: nil,
            playbackTime: 0,
            duration: duration,
            isPlaying: false,
            repeatMode: .off,
            shuffleEnabled: false,
            updatedAt: Date()
        )
    }

    func clearState() throws {
        state = nil
    }
}

/// Отключает чтение AppSettings в тестах контекста воспроизведения.
@MainActor
private final class PlaybackModePersistenceSpy: PlaybackModePersisting {
    func loadPlaybackMode() -> PlaybackMode {
        PlaybackMode(isShuffleEnabled: false, repeatMode: .off)
    }

    func savePlaybackMode(_ mode: PlaybackMode) {}
}

/// Не подписывается на NotificationCenter и предоставляет ViewModel нужные свойства обратных вызовов.
@MainActor
private final class PlayerEventObserverSpy: PlayerEventObserving {
    var onTrackDurationUpdated: ((TimeInterval) -> Void)?
    var onTrackDidFinish: (() -> Void)?
    var onTrackDidUpdate: ((TrackUpdateEvent) -> Void)?
    var onSettingsChanged: (() -> Void)?
}

/// Не показывает UI-сообщения: waveform не должен создавать пользовательские ошибки.
@MainActor
private final class ToastPresenterSpy: ToastPresenting {
    func handle(_ event: ToastEvent, duration: TimeInterval) {}

    func handle(_ error: AppError) {}
}

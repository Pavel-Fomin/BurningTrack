//
//  TrackDetailFlowTests.swift
//  TrackList
//
//  Focused-проверки command и presentation flow Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import Combine
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import TrackList

/// Проверяет правила сохранения Track Detail через явные feature-local зависимости.
@MainActor
final class TrackDetailFlowTests: XCTestCase {

    func testSavePreservesOriginalExtensionAndWritesValidYear() async {
        let executor = TrackDetailExecutorSpy()
        let handler = makeActionHandler(executor: executor)
        let trackId = UUID()
        var values = baselineValues()
        values[.title] = "  Updated Title  "
        values[.year] = " 2026 "

        let presentation = await handler.save(
            makeDraft(
                trackId: trackId,
                fileName: "  Updated File  ",
                editableValues: values
            )
        )

        guard case let .saved(snapshot) = presentation else {
            return XCTFail("Успешная команда должна подтвердить сохранение")
        }
        XCTAssertNil(snapshot)

        let requests = executor.requests()
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests[0].newFileName, "Updated File.flac")
        XCTAssertTrue(requests[0].fileChanged)
        XCTAssertTrue(requests[0].tagsChanged)
        XCTAssertEqual(requests[0].patch.title, .set("Updated Title"))
        XCTAssertEqual(requests[0].patch.year, .set(2026))
    }

    func testInvalidYearDoesNotExecuteOrClearTag() async {
        let executor = TrackDetailExecutorSpy()
        let handler = makeActionHandler(executor: executor)
        var values = baselineValues()
        values[.year] = "twenty twenty six"

        let presentation = await handler.save(
            makeDraft(editableValues: values)
        )

        guard case let .keepEditing(alert) = presentation else {
            return XCTFail("Невалидный год не должен запускать сохранение")
        }
        XCTAssertNil(alert)
        let requests = executor.requests()
        XCTAssertTrue(requests.isEmpty)
    }

    func testFileNameConflictKeepsDraftOpenWithoutReleasingPlayback() async {
        let executor = TrackDetailExecutorSpy()
        executor.setOutcomes([.appError(.fileAlreadyExists)])
        let releaser = TrackDetailPlaybackReleaserSpy()
        let handler = makeActionHandler(
            executor: executor,
            playbackFileReleaser: releaser
        )

        let presentation = await handler.save(
            makeDraft(fileName: "Conflicting File")
        )

        guard case let .keepEditing(alert) = presentation else {
            return XCTFail("Конфликт имени должен оставить форму открытой")
        }
        XCTAssertEqual(alert, .fileNameConflict)
        XCTAssertEqual(releaser.releaseCount, 0)
        let requests = executor.requests()
        XCTAssertEqual(requests.count, 1)
    }

    func testConfirmedStopPlaybackRepeatsExactPendingCommand() async {
        let executor = TrackDetailExecutorSpy()
        executor.setOutcomes([.appError(.fileAccessDenied), .success])
        let releaser = TrackDetailPlaybackReleaserSpy()
        let handler = makeActionHandler(
            executor: executor,
            playbackFileReleaser: releaser
        )
        var values = baselineValues()
        values[.artist] = "Changed Artist"

        let firstPresentation = await handler.save(
            makeDraft(
                fileName: "Changed File",
                editableValues: values
            )
        )
        let retryPresentation = await handler.confirmStopPlayback()

        guard case let .keepEditing(alert) = firstPresentation else {
            return XCTFail("Занятый файл должен запросить остановку playback")
        }
        XCTAssertEqual(alert, .stopPlayback)
        guard case .saved = retryPresentation else {
            return XCTFail("Повтор после остановки плеера должен завершить сохранение")
        }
        XCTAssertEqual(releaser.releaseCount, 1)

        let requests = executor.requests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[0], requests[1])
    }

    func testPresenterKeepsRawArtworkRemovableWhenPreviewCannotBeDecoded() {
        let presenter = TrackDetailPresenter(
            toastPresenter: TrackDetailToastSpy()
        )
        let artworkState = ArtworkEditState(hadOriginalArtwork: true)

        let presentation = presenter.makeArtworkPresentation(
            trackId: UUID(),
            originalArtworkRequest: nil,
            hasOriginalArtwork: true,
            artworkEditState: artworkState
        )

        XCTAssertNil(presentation.request)
        XCTAssertFalse(presentation.canAddArtwork)
        XCTAssertTrue(presentation.canRemoveArtwork)
    }

    /// Snapshot с raw artwork формирует request крупного Track Detail preview без UIImage в state.
    func testLoadedPresentationCreatesLargeOriginalArtworkRequest() {
        let trackId = UUID()
        let artworkData = Data([1, 2, 3])
        let presenter = TrackDetailPresenter(toastPresenter: TrackDetailToastSpy())

        let presentation = presenter.makeLoadedPresentation(
            snapshot: makeConfirmedTrackDetailSnapshot(
                trackId: trackId,
                fileName: "Original.flac",
                artworkData: artworkData
            ),
            fileURL: URL(fileURLWithPath: "/tmp/Original.flac")
        )

        let request = presentation.originalArtworkRequest
        XCTAssertEqual(request?.trackId, trackId)
        XCTAssertEqual(request?.artworkData, artworkData)
        XCTAssertEqual(request?.purpose, .trackInfoSheet)
        XCTAssertEqual(request?.sizeClass, .large)
    }

    /// Переход view → edit → cancel сохраняет исходный request между обоими presentation-режимами.
    func testViewEditAndCancelRetainOriginalArtworkRequest() async {
        let track = TrackDetailLocalTrack()
        let originalData = Data([1, 2, 3])
        let snapshot = makeConfirmedTrackDetailSnapshot(
            trackId: track.trackId,
            fileName: track.fileName,
            artworkData: originalData
        )
        let viewModel = makeArtworkViewModel(track: track, snapshot: snapshot)

        viewModel.send(.appeared)
        await completeScheduledTask()
        let viewRequest = viewModel.state.artwork.request

        viewModel.send(.editTapped)
        let editRequest = viewModel.state.artwork.request

        viewModel.send(.closeTapped)
        let cancelledEditRequest = viewModel.state.artwork.request

        XCTAssertEqual(viewModel.state.mode, .view)
        XCTAssertEqual(viewRequest, editRequest)
        XCTAssertEqual(editRequest, cancelledEditRequest)
        XCTAssertEqual(viewRequest?.artworkData, originalData)
    }

    /// Внешнее подтверждённое обновление artwork заменяет request текущего режима просмотра.
    func testExternalSnapshotUpdateReplacesOriginalArtworkRequest() async {
        let track = TrackDetailLocalTrack()
        let initialSnapshot = makeConfirmedTrackDetailSnapshot(
            trackId: track.trackId,
            fileName: track.fileName,
            artworkData: Data([1, 2, 3])
        )
        let events = TrackDetailEventProviderSpy()
        let viewModel = makeArtworkViewModel(
            track: track,
            snapshot: initialSnapshot,
            eventProvider: events
        )

        viewModel.send(.appeared)
        await completeScheduledTask()
        let initialRequest = viewModel.state.artwork.request
        let updatedData = Data([4, 5, 6])
        let updatedSnapshot = makeConfirmedTrackDetailSnapshot(
            trackId: track.trackId,
            fileName: track.fileName,
            artworkData: updatedData
        )

        events.trackDidUpdateSubject.send(
            TrackUpdateEvent(
                trackId: track.trackId,
                reason: .artworkUpdated,
                changedFields: [.artworkData],
                snapshot: updatedSnapshot
            )
        )

        XCTAssertNotEqual(viewModel.state.artwork.request, initialRequest)
        XCTAssertEqual(viewModel.state.artwork.request?.artworkData, updatedData)
        XCTAssertEqual(viewModel.state.artwork.request?.sizeClass, .large)
    }

    /// Несохранённая замена использует transient identity, а локальное удаление возвращает nil request.
    func testReplacementUsesTransientArtworkRequestAndRemovalClearsIt() async {
        let track = TrackDetailLocalTrack()
        let snapshot = makeConfirmedTrackDetailSnapshot(
            trackId: track.trackId,
            fileName: track.fileName,
            artworkData: Data([1, 2, 3])
        )
        let viewModel = makeArtworkViewModel(track: track, snapshot: snapshot)
        let replacementData = Data([7, 8, 9])
        let revision = UUID()

        viewModel.send(.appeared)
        await completeScheduledTask()
        viewModel.send(.editTapped)
        viewModel.send(.artworkSelected(data: replacementData, revision: revision))

        XCTAssertEqual(
            viewModel.state.artwork.request?.sourceIdentifier,
            .transient(revision: revision)
        )
        XCTAssertEqual(viewModel.state.artwork.request?.artworkData, replacementData)
        XCTAssertEqual(viewModel.state.artwork.request?.sizeClass, .large)

        viewModel.send(.artworkRemoveTapped)

        XCTAssertNil(viewModel.state.artwork.request)
        XCTAssertTrue(viewModel.state.artwork.canAddArtwork)
        XCTAssertFalse(viewModel.state.artwork.canRemoveArtwork)
    }

    /// Read-only экран запускает общий artwork pipeline через Environment один раз на request.
    func testReadOnlyViewLoadsArtworkFromEnvironment() async {
        let trackId = UUID()
        let artworkData = Data([1, 2, 3])
        let request = ArtworkRequest(
            trackId: trackId,
            artworkData: artworkData,
            purpose: .trackInfoSheet,
            sourceIdentifier: .embeddedArtwork(data: artworkData)
        )
        let providerExpectation = expectation(
            description: "Read-only View передаёт artwork request в Environment provider"
        )
        // XCTest ожидает реальный вызов provider из SwiftUI lifecycle, а не искусственную паузу.
        providerExpectation.assertForOverFulfill = false
        let provider = TrackDetailArtworkProviderSpy(
            onRequest: providerExpectation.fulfill
        )
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else {
            return XCTFail("Для lifecycle-проверки нужен активный UIWindowScene")
        }
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = UIHostingController(
            rootView: TrackDetailReadOnlyView(
                state: makeReadOnlyState(artworkRequest: request)
            )
            .environment(\.artworkImageProvider, provider)
        )
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        await fulfillment(of: [providerExpectation], timeout: 2)
        // Completion изображения не должен пересоздавать read-only artwork и запускать тот же provider заново.
        try? await Task.sleep(nanoseconds: 150_000_000)

        let loadedRequest = provider.request
        XCTAssertEqual(loadedRequest, request)
        XCTAssertEqual(provider.requests, [request])
    }

    func testDirectEditRouteKeepsPurchasedITunesTrackReadOnly() async {
        let purchasedTrack = PurchasedITunesPlayableTrack(
            track: PurchasedITunesTrack(
                id: 42,
                title: "Purchased Track",
                artist: "Artist",
                album: "Album",
                year: nil,
                genre: nil,
                dateAdded: Date(timeIntervalSince1970: 0),
                artworkData: nil,
                duration: 180,
                assetURL: URL(fileURLWithPath: "/tmp/purchased.m4a")
            )
        )
        let snapshot = TrackRuntimeSnapshot(
            purchasedITunesTrack: purchasedTrack,
            technicalMetadata: TrackTechnicalMetadata(
                fileSizeBytes: nil,
                fileFormat: nil,
                bitrateBitsPerSecond: nil
            )
        )
        let executor = TrackDetailExecutorSpy()
        let toast = TrackDetailToastSpy()
        let presenter = TrackDetailPresenter(toastPresenter: toast)
        let handler = TrackDetailActionHandler(
            snapshotProvider: TrackDetailSnapshotProviderSpy(),
            snapshotBuilder: TrackDetailSnapshotBuilderSpy(
                purchasedSnapshot: snapshot
            ),
            fileURLResolver: TrackDetailFileURLResolverSpy(),
            commandExecutor: executor,
            fileBusyChecker: TrackDetailBusyCheckerSpy(),
            playbackFileReleaser: TrackDetailPlaybackReleaserSpy(),
            presenter: presenter,
            router: TrackDetailRouterSpy()
        )
        let viewModel = TrackDetailViewModel(
            track: purchasedTrack,
            initialMode: .edit,
            presenter: presenter,
            actionHandler: handler,
            eventProvider: TrackDetailEmptyEventProvider()
        )

        viewModel.send(.appeared)
        await completeScheduledTask()

        XCTAssertEqual(viewModel.state.mode, .view)
        XCTAssertFalse(viewModel.state.canEnterEdit)
        XCTAssertFalse(viewModel.state.canSave)
    }

    func testBatchUpdateAppliesOnlySnapshotOfPresentedTrack() {
        let track = TrackDetailLocalTrack()
        let events = TrackDetailEventProviderSpy()
        let executor = TrackDetailExecutorSpy()
        let presenter = TrackDetailPresenter(toastPresenter: TrackDetailToastSpy())
        let viewModel = TrackDetailViewModel(
            track: track,
            initialMode: .view,
            presenter: presenter,
            actionHandler: makeActionHandler(executor: executor),
            eventProvider: events
        )

        events.trackBatchDidUpdateSubject.send([
            TrackUpdateEvent(
                trackId: UUID(),
                reason: .metadataUpdated,
                changedFields: [.title],
                snapshot: makeConfirmedTrackDetailSnapshot(
                    trackId: UUID(),
                    fileName: "Unrelated.flac"
                )
            ),
            TrackUpdateEvent(
                trackId: track.trackId,
                reason: .metadataUpdated,
                changedFields: [.title],
                snapshot: makeConfirmedTrackDetailSnapshot(
                    trackId: track.trackId,
                    fileName: "Batch Updated.flac"
                )
            )
        ])

        XCTAssertEqual(viewModel.state.fileName, "Batch Updated")
    }

    private func makeActionHandler(
        executor: TrackDetailExecutorSpy,
        playbackFileReleaser: TrackDetailPlaybackReleaserSpy? = nil,
        snapshotBuilder: any TrackDetailSnapshotBuilding = TrackDetailSnapshotBuilderSpy(),
        snapshotProvider: any TrackDetailSnapshotProviding = TrackDetailSnapshotProviderSpy(),
        fileURLResolver: any TrackDetailFileURLResolving = TrackDetailFileURLResolverSpy()
    ) -> TrackDetailActionHandler {
        let toast = TrackDetailToastSpy()
        return TrackDetailActionHandler(
            snapshotProvider: snapshotProvider,
            snapshotBuilder: snapshotBuilder,
            fileURLResolver: fileURLResolver,
            commandExecutor: executor,
            fileBusyChecker: TrackDetailBusyCheckerSpy(),
            playbackFileReleaser: playbackFileReleaser
                ?? TrackDetailPlaybackReleaserSpy(),
            presenter: TrackDetailPresenter(toastPresenter: toast),
            router: TrackDetailRouterSpy()
        )
    }

    /// Собирает feature graph с готовым artwork snapshot без production store и файлового доступа.
    private func makeArtworkViewModel(
        track: TrackDetailLocalTrack,
        snapshot: TrackRuntimeSnapshot,
        eventProvider: any TrackDetailEventProviding = TrackDetailEmptyEventProvider()
    ) -> TrackDetailViewModel {
        let presenter = TrackDetailPresenter(toastPresenter: TrackDetailToastSpy())
        let actionHandler = makeActionHandler(
            executor: TrackDetailExecutorSpy(),
            snapshotProvider: TrackDetailSnapshotProviderSpy(snapshot: snapshot),
            fileURLResolver: TrackDetailFileURLResolverSpy(
                fileURL: URL(fileURLWithPath: "/tmp/\(track.fileName)")
            )
        )
        return TrackDetailViewModel(
            track: track,
            initialMode: .view,
            presenter: presenter,
            actionHandler: actionHandler,
            eventProvider: eventProvider
        )
    }

    /// Формирует минимальное готовое read-only состояние для проверки presentation lifecycle.
    private func makeReadOnlyState(
        artworkRequest: ArtworkRequest
    ) -> TrackDetailScreenState {
        TrackDetailScreenState(
            mode: .view,
            isLoading: false,
            isSaving: false,
            canEnterEdit: true,
            canSave: false,
            fileName: "Track",
            editableValues: [:],
            filePath: nil,
            technicalInfo: "",
            artwork: TrackDetailArtworkPresentationState(
                request: artworkRequest,
                canAddArtwork: false,
                canRemoveArtwork: true
            ),
            canUseFileNameStrategies: false,
            yearValidationMessage: nil,
            alert: nil
        )
    }

    private func makeDraft(
        trackId: UUID = UUID(),
        fileName: String = "Original",
        editableValues: [EditableTrackField: String]? = nil
    ) -> TrackDetailSaveDraft {
        let baselineArtwork = ArtworkEditState(hadOriginalArtwork: false)
        return TrackDetailSaveDraft(
            trackId: trackId,
            baselineFullFileName: "Original.flac",
            baselineFileName: "Original",
            baselineValues: baselineValues(),
            baselineArtwork: baselineArtwork,
            fileName: fileName,
            editableValues: editableValues ?? baselineValues(),
            artwork: baselineArtwork
        )
    }

    private func baselineValues() -> [EditableTrackField: String] {
        [
            .title: "Original Title",
            .artist: "Original Artist",
            .album: "Original Album",
            .genre: "Original Genre",
            .year: "2020",
            .publisher: "Original Label",
            .comment: "Original Comment"
        ]
    }

    private func completeScheduledTask() async {
        try? await Task.sleep(nanoseconds: 100_000_000)

        for _ in 0..<8 {
            await Task.yield()
        }
    }
}

/// MainActor-double запоминает вызовы существующего save-command вместо файловой операции.
@MainActor
private final class TrackDetailExecutorSpy: TrackDetailCommandExecuting {
    private var outcomes: [TrackDetailExecutorOutcome] = [.success]
    private var saveRequests: [TrackDetailSaveRequest] = []

    func setOutcomes(_ outcomes: [TrackDetailExecutorOutcome]) {
        self.outcomes = outcomes
    }

    func requests() -> [TrackDetailSaveRequest] {
        saveRequests
    }

    func saveTrackEdits(
        trackId: UUID,
        newFileName: String,
        fileChanged: Bool,
        patch: TagWritePatch,
        tagsChanged: Bool,
        artworkAction: ArtworkWriteAction,
        artworkChanged: Bool,
        using fileBusyChecker: any TrackFileBusyChecking
    ) async throws -> TrackEditsSavedSuccess {
        saveRequests.append(
            TrackDetailSaveRequest(
                trackId: trackId,
                newFileName: newFileName,
                fileChanged: fileChanged,
                patch: patch,
                tagsChanged: tagsChanged,
                artworkAction: artworkAction,
                artworkChanged: artworkChanged
            )
        )

        let outcome = outcomes.isEmpty ? .success : outcomes.removeFirst()
        switch outcome {
        case .success:
            return TrackEditsSavedSuccess(
                trackId: trackId,
                finalFileName: newFileName,
                snapshot: makeConfirmedTrackDetailSnapshot(
                    trackId: trackId,
                    fileName: newFileName
                ),
                didUpdateTagsOrArtwork: tagsChanged || artworkChanged
            )

        case let .appError(error):
            throw error
        }
    }
}

/// Создаёт новый snapshot, который test double возвращает только для confirmed save-result.
private func makeConfirmedTrackDetailSnapshot(
    trackId: UUID,
    fileName: String,
    artworkData: Data? = nil
) -> TrackRuntimeSnapshot {
    TrackRuntimeSnapshot(
        trackId: trackId,
        fileName: fileName,
        isAvailable: true,
        technicalMetadata: TrackTechnicalMetadata(
            fileSizeBytes: nil,
            fileFormat: "MP3",
            bitrateBitsPerSecond: nil
        ),
        title: "Track",
        artist: "Artist",
        album: nil,
        albumArtist: nil,
        genre: nil,
        comment: nil,
        composer: nil,
        conductor: nil,
        lyricist: nil,
        remixer: nil,
        grouping: nil,
        bpm: nil,
        musicalKey: nil,
        trackNumber: nil,
        totalTracks: nil,
        discNumber: nil,
        totalDiscs: nil,
        year: nil,
        date: nil,
        publisherOrLabel: nil,
        copyright: nil,
        encodedBy: nil,
        isrc: nil,
        duration: nil,
        artworkData: artworkData,
        artworkSourceIdentifier: artworkData.map(ArtworkSourceIdentifier.embeddedArtwork),
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}

/// Результат следующего вызова fake command executor.
private enum TrackDetailExecutorOutcome {
    case success
    case appError(AppError)
}

/// Снимок параметров write-команды, достаточный для проверки повторного вызова.
private struct TrackDetailSaveRequest: Equatable {
    let trackId: UUID
    let newFileName: String
    let fileChanged: Bool
    let patch: TagWritePatch
    let tagsChanged: Bool
    let artworkAction: ArtworkWriteAction
    let artworkChanged: Bool
}

/// Предоставляет пустой runtime-cache: тесты проверяют только командный flow.
@MainActor
private final class TrackDetailSnapshotProviderSpy: TrackDetailSnapshotProviding {
    /// Snapshot возвращается только соответствующему тестовому треку.
    private let loadedSnapshot: TrackRuntimeSnapshot?

    /// Создаёт provider с необязательным готовым runtime snapshot.
    init(snapshot: TrackRuntimeSnapshot? = nil) {
        loadedSnapshot = snapshot
    }

    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        guard loadedSnapshot?.trackId == trackId else { return nil }
        return loadedSnapshot
    }
}

/// Фиксирует request и завершает XCTest только после реального вызова provider из SwiftUI lifecycle.
@MainActor
private final class TrackDetailArtworkProviderSpy: ArtworkImageProviding {
    /// Последний request, полученный через Environment-boundary.
    private(set) var request: ArtworkRequest?
    /// Все вызовы позволяют проверить, что повторный lifecycle не подменил identity обложки.
    private(set) var requests: [ArtworkRequest] = []
    /// Внешний сигнал даёт тесту ожидать run-loop, а не угадывать число Task.yield.
    private let onRequest: () -> Void

    init(onRequest: @escaping () -> Void) {
        self.onRequest = onRequest
    }

    func image(for request: ArtworkRequest) async -> UIImage? {
        self.request = request
        requests.append(request)
        onRequest()
        return UIImage()
    }
}

/// Не должен участвовать в save-тестах, но завершает dependency graph обработчика.
private final class TrackDetailSnapshotBuilderSpy: TrackDetailSnapshotBuilding {
    private let purchasedSnapshot: TrackRuntimeSnapshot?

    init(purchasedSnapshot: TrackRuntimeSnapshot? = nil) {
        self.purchasedSnapshot = purchasedSnapshot
    }

    func buildSnapshot(forTrackId trackId: UUID) async throws -> TrackRuntimeSnapshot? {
        nil
    }

    func buildSnapshot(
        forPurchasedITunesTrack track: PurchasedITunesPlayableTrack
    ) async -> TrackRuntimeSnapshot {
        guard let purchasedSnapshot else {
            fatalError("Purchased iTunes snapshot не нужен в save-тестах")
        }
        return purchasedSnapshot
    }
}

/// Не должен участвовать в save-тестах, но завершает dependency graph обработчика.
private struct TrackDetailFileURLResolverSpy: TrackDetailFileURLResolving {
    /// Заранее подготовленный file URL нужен только для presentation-пути загрузки.
    private let resolvedURL: URL?

    /// Создаёт resolver с контролируемым результатом без обращения к BookmarkResolver.
    init(fileURL: URL? = nil) {
        resolvedURL = fileURL
    }

    func fileURL(forTrackId trackId: UUID) async -> URL? {
        resolvedURL
    }
}

/// Возвращает незанятое состояние файла для передачи существующей capability.
@MainActor
private final class TrackDetailBusyCheckerSpy: TrackFileBusyChecking {
    func isTrackFileBusy(trackId: UUID) -> Bool {
        false
    }
}

/// Запоминает освобождение файла после явного подтверждения alert.
@MainActor
private final class TrackDetailPlaybackReleaserSpy: CurrentPlaybackFileReleasing {
    var releaseCount = 0

    func releaseCurrentPlaybackFile() {
        releaseCount += 1
    }
}

/// Запоминает сообщения presenter-а без показа UI.
@MainActor
private final class TrackDetailToastSpy: ToastPresenting {
    func handle(_ event: ToastEvent, duration: TimeInterval) {}
    func handle(_ error: AppError) {}
}

/// Завершает dependency graph обработчика без обращения к SheetManager.
@MainActor
private final class TrackDetailRouterSpy: TrackDetailRouting {
    func dismissTrackDetail(_ routeID: UUID) {}
}

/// Передаёт пустой поток обновлений для изолированной проверки стартового route.
@MainActor
private struct TrackDetailEmptyEventProvider: TrackDetailEventProviding {
    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }

    var trackBatchDidUpdate: AnyPublisher<[TrackUpdateEvent], Never> {
        Empty(completeImmediately: true).eraseToAnyPublisher()
    }
}

/// Передаёт контролируемые runtime-события в изолированный Track Detail тест.
@MainActor
private final class TrackDetailEventProviderSpy: TrackDetailEventProviding {
    let trackDidUpdateSubject = PassthroughSubject<TrackUpdateEvent, Never>()
    let trackBatchDidUpdateSubject = PassthroughSubject<[TrackUpdateEvent], Never>()

    var trackDidUpdate: AnyPublisher<TrackUpdateEvent, Never> {
        trackDidUpdateSubject.eraseToAnyPublisher()
    }

    var trackBatchDidUpdate: AnyPublisher<[TrackUpdateEvent], Never> {
        trackBatchDidUpdateSubject.eraseToAnyPublisher()
    }
}

/// Представляет локальный трек без зависимости теста от SQLite-модели.
private struct TrackDetailLocalTrack: TrackDisplayable {
    let id = UUID()
    let trackId = UUID()
    let fileName = "Original.flac"
    let title: String? = "Original"
    let artist: String? = "Artist"
    let duration = 180.0
    let isAvailable = true
}

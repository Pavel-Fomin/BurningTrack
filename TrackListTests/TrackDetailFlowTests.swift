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

    private func makeActionHandler(
        executor: TrackDetailExecutorSpy,
        playbackFileReleaser: TrackDetailPlaybackReleaserSpy? = nil,
        snapshotBuilder: any TrackDetailSnapshotBuilding = TrackDetailSnapshotBuilderSpy()
    ) -> TrackDetailActionHandler {
        let toast = TrackDetailToastSpy()
        return TrackDetailActionHandler(
            snapshotProvider: TrackDetailSnapshotProviderSpy(),
            snapshotBuilder: snapshotBuilder,
            fileURLResolver: TrackDetailFileURLResolverSpy(),
            commandExecutor: executor,
            fileBusyChecker: TrackDetailBusyCheckerSpy(),
            playbackFileReleaser: playbackFileReleaser
                ?? TrackDetailPlaybackReleaserSpy(),
            presenter: TrackDetailPresenter(toastPresenter: toast),
            router: TrackDetailRouterSpy()
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
                snapshot: nil,
                didUpdateTagsOrArtwork: tagsChanged || artworkChanged
            )

        case let .appError(error):
            throw error
        }
    }
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
    func snapshot(forTrackId trackId: UUID) -> TrackRuntimeSnapshot? {
        nil
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
    func fileURL(forTrackId trackId: UUID) async -> URL? {
        nil
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
}

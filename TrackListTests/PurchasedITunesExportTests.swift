//
//  PurchasedITunesExportTests.swift
//  TrackListTests
//
//  Проверки обычного экспорта раздела «Куплено в iTunes».
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Combine
import Foundation
import XCTest
@testable import TrackList

/// Проверяет экранный маршрут и файловую ветку iTunes без системного picker-а.
final class PurchasedITunesExportTests: XCTestCase {

    /// Проверяет прямую запись assetURL и существующий формат имён без BookmarkResolver.
    func testServiceExportsPurchasedAssetsWithArtistTitleFileNames() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "PurchasedITunesExportTests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        defer {
            try? FileManager.default.removeItem(at: rootURL)
        }

        let firstData = Data("first".utf8)
        let secondData = Data("second".utf8)
        let firstSourceURL = rootURL.appendingPathComponent("source-one.m4a")
        let secondSourceURL = rootURL.appendingPathComponent("source-two.m4a")
        try firstData.write(to: firstSourceURL)
        try secondData.write(to: secondSourceURL)

        let firstTrack = makeExportTrack(
            title: "One",
            artist: "Artist",
            assetURL: firstSourceURL
        )
        let secondTrack = makeExportTrack(
            title: "Two",
            artist: nil,
            assetURL: secondSourceURL
        )
        let job = ExportJob(
            tracks: [firstTrack, secondTrack],
            destination: ExportDestination(folderURL: rootURL),
            exportFolder: .purchasedITunes,
            fileNamingMode: .original
        )

        // Типизированный source фиксирует прямой runtime URL ещё до запуска сервиса.
        guard case .purchasedITunes(_, let firstAsset) = job.items[0].source else {
            return XCTFail("Первый iTunes-трек попал в bookmark-ветку")
        }
        XCTAssertEqual(firstAsset?.sourceURL, firstSourceURL)

        let summary = try await TrackExportService().export(job: job)
        let exportFolderURL = rootURL.appendingPathComponent(
            "Purchased iTunes",
            isDirectory: true
        )
        let firstDestinationURL = exportFolderURL
            .appendingPathComponent("Artist - One.m4a")
        let secondDestinationURL = exportFolderURL
            .appendingPathComponent("Two.m4a")

        XCTAssertEqual(summary.completedFiles, 2)
        XCTAssertTrue(summary.failedFiles.isEmpty)
        XCTAssertEqual(summary.state, .completed)
        XCTAssertEqual(try Data(contentsOf: firstDestinationURL), firstData)
        XCTAssertEqual(try Data(contentsOf: secondDestinationURL), secondData)
    }

    /// Создаёт transport-модель с отдельным iTunes source и готовым assetURL.
    private func makeExportTrack(
        title: String,
        artist: String?,
        assetURL: URL
    ) -> Track {
        Track(
            trackId: UUID(),
            title: title,
            artist: artist,
            duration: 1,
            fileName: title,
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: assetURL
        )
    }
}

/// Проверяет экранный ActionHandler через существующее глобальное состояние экспорта.
@MainActor
final class PurchasedITunesMusicActionHandlerTests: XCTestCase {

    /// Проверяет папку, original-режим, порядок и сохранение прямых assetURL.
    func testExportUsesAllTracksInDisplayOrderWithoutNumbering() async {
        let exportRequestHandler = ExportRequestHandlerSpy()
        let firstSourceTrack = makeSourceTrack(
            id: 1,
            title: "First",
            artist: "Artist",
            assetURL: URL(fileURLWithPath: "/tmp/first.m4a")
        )
        let secondSourceTrack = makeSourceTrack(
            id: 2,
            title: "Second",
            artist: nil,
            assetURL: URL(fileURLWithPath: "/tmp/second.m4a")
        )
        let viewModel = makeViewModel(
            tracks: [secondSourceTrack, firstSourceTrack]
        )
        await viewModel.load()
        let displayOrder = viewModel.screenState.tracks
        let handler = PurchasedITunesMusicActionHandler(
            viewModel: viewModel,
            exportRequestHandler: exportRequestHandler
        )
        handler.handle(.exportTracks)

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.trackId),
            displayOrder.map(\.trackId)
        )
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.source),
            [.purchasedITunes, .purchasedITunes]
        )
        XCTAssertEqual(
            exportRequestHandler.requests.first?.tracks.map(\.assetURL),
            displayOrder.map(\.assetURL)
        )
        XCTAssertEqual(exportRequestHandler.requests.first?.exportFolder, .purchasedITunes)
        guard let fileNamingMode = exportRequestHandler.requests.first?.fileNamingMode else {
            return XCTFail("Режим именования не передан в общий экспорт")
        }
        guard case .original = fileNamingMode else {
            return XCTFail("Для iTunes ожидался обычный режим original")
        }
    }

    /// Проверяет передачу пустого раздела в единый ingress глобальной валидации.
    func testEmptySectionPassesEmptyRequestToGlobalValidation() async {
        let exportRequestHandler = ExportRequestHandlerSpy()
        let viewModel = makeViewModel(tracks: [])
        await viewModel.load()
        let handler = PurchasedITunesMusicActionHandler(
            viewModel: viewModel,
            exportRequestHandler: exportRequestHandler
        )

        handler.handle(.exportTracks)

        XCTAssertEqual(exportRequestHandler.requests.count, 1)
        XCTAssertTrue(exportRequestHandler.requests.first?.tracks.isEmpty == true)
    }

    /// Проверяет, что load и сортировка проходят через типизированный экранный handler.
    func testAppearedAndSortActionsUpdateFeatureViewModel() async {
        let firstSourceTrack = makeSourceTrack(
            id: 1,
            title: "Beta",
            artist: "Alpha",
            assetURL: URL(fileURLWithPath: "/tmp/beta.m4a")
        )
        let secondSourceTrack = makeSourceTrack(
            id: 2,
            title: "Alpha",
            artist: "Beta",
            assetURL: URL(fileURLWithPath: "/tmp/alpha.m4a")
        )
        let provider = PurchasedITunesMusicActionProviderStub(
            tracks: [firstSourceTrack, secondSourceTrack]
        )
        let viewModel = makeViewModel(provider: provider)
        let handler = PurchasedITunesMusicActionHandler(
            viewModel: viewModel,
            exportRequestHandler: ExportRequestHandlerSpy()
        )

        handler.handle(.appeared)
        await yieldToExportTask()
        handler.handle(.sortModeSelected(.artistDesc))

        XCTAssertEqual(provider.loadTracksCallCount, 1)
        XCTAssertEqual(viewModel.screenState.sortMode, .artistDesc)
        XCTAssertEqual(
            viewModel.screenState.tracks.map(\.title),
            ["Alpha", "Beta"]
        )
    }

    /// Создаёт runtime-адаптер без обращения к MediaPlayer.
    private func makePlayableTrack(
        id: UInt64,
        title: String,
        artist: String?,
        assetURL: URL
    ) -> PurchasedITunesPlayableTrack {
        PurchasedITunesPlayableTrack(
            track: makeSourceTrack(
                id: id,
                title: title,
                artist: artist,
                assetURL: assetURL
            )
        )
    }

    /// Создаёт исходную runtime-модель для загрузки ViewModel без MediaPlayer.
    private func makeSourceTrack(
        id: UInt64,
        title: String,
        artist: String?,
        assetURL: URL
    ) -> PurchasedITunesTrack {
        PurchasedITunesTrack(
            id: id,
            title: title,
            artist: artist,
            album: nil,
            year: nil,
            genre: nil,
            dateAdded: Date(timeIntervalSince1970: 0),
            artworkData: nil,
            duration: 1,
            assetURL: assetURL
        )
    }

    /// Собирает ViewModel с явными тестовыми runtime-зависимостями.
    private func makeViewModel(
        tracks: [PurchasedITunesTrack]
    ) -> PurchasedITunesMusicViewModel {
        makeViewModel(
            provider: PurchasedITunesMusicActionProviderStub(tracks: tracks)
        )
    }

    /// Собирает ViewModel с переданным provider-ом для проверки запуска загрузки через handler.
    private func makeViewModel(
        provider: PurchasedITunesMusicActionProviderStub
    ) -> PurchasedITunesMusicViewModel {
        PurchasedITunesMusicViewModel(
            provider: provider,
            sortModePersistence: PurchasedITunesMusicActionSortPersistenceStub(),
            favoriteTrackIdsProvider: PurchasedITunesMusicActionFavoriteProviderStub(),
            playbackStateProvider: PurchasedITunesMusicActionPlaybackProviderStub(),
            presenter: PurchasedITunesPresenter(
                artworkBadgeStateFactory: TrackArtworkBadgeStateFactory()
            )
        )
    }

    /// Даёт глобальному coordinator завершить тестовую задачу экспорта.
    private func yieldToExportTask() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}

/// Подменяет чтение медиатеки и фиксирует единственное обращение handler-а к ViewModel.
private final class PurchasedITunesMusicActionProviderStub: PurchasedITunesMusicProviding {
    let tracks: [PurchasedITunesTrack]
    private(set) var loadTracksCallCount = 0

    init(tracks: [PurchasedITunesTrack]) {
        self.tracks = tracks
    }

    func accessState() -> PurchasedITunesMusicAccessState { .authorized }
    func requestAccessIfNeeded() async -> PurchasedITunesMusicAccessState { .authorized }

    func loadTracks() -> [PurchasedITunesTrack] {
        loadTracksCallCount += 1
        return tracks
    }
}

/// Хранит сортировку в памяти, чтобы тест экранного handler-а не затрагивал SQLite.
@MainActor
private final class PurchasedITunesMusicActionSortPersistenceStub: PurchasedITunesTrackSortModePersisting {
    private(set) var purchasedITunesTrackSortMode: PurchasedITunesTrackSortMode = .titleAsc

    func setPurchasedITunesTrackSortMode(_ mode: PurchasedITunesTrackSortMode) throws {
        purchasedITunesTrackSortMode = mode
    }
}

/// Отдаёт пустое подтверждённое избранное без PlayerViewModel.
@MainActor
private final class PurchasedITunesMusicActionFavoriteProviderStub: FavoriteTrackIdsProviding {
    private let subject = CurrentValueSubject<Set<UUID>, Never>([])

    var favoriteTrackIds: Set<UUID> { subject.value }

    var favoriteTrackIdsPublisher: AnyPublisher<Set<UUID>, Never> {
        subject.eraseToAnyPublisher()
    }
}

/// Отдаёт нейтральный playback-снимок, достаточный для подготовки ScreenState.
@MainActor
private final class PurchasedITunesMusicActionPlaybackProviderStub: PlaybackStateProviding {
    private let subject = CurrentValueSubject<PlaybackStateSnapshot, Never>(
        PlaybackStateSnapshot(
            currentDisplayableId: nil,
            currentTrackId: nil,
            currentContext: nil,
            currentContextSource: nil,
            isPlaying: false
        )
    )

    var playbackState: PlaybackStateSnapshot { subject.value }
    var currentDisplayableId: UUID? { playbackState.currentDisplayableId }
    var currentTrackId: UUID? { playbackState.currentTrackId }
    var currentContext: PlaybackContext? { playbackState.currentContext }
    var currentContextSource: PlaybackContextSource? { playbackState.currentContextSource }
    var isPlaying: Bool { playbackState.isPlaying }

    var playbackStatePublisher: AnyPublisher<PlaybackStateSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }
}

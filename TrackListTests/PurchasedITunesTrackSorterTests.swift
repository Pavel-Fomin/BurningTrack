//
//  PurchasedITunesTrackSorterTests.swift
//  TrackListTests
//
//  Проверки сортировки и повторного использования загруженных iTunes-треков.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Combine
import XCTest
@testable import TrackList

final class PurchasedITunesTrackSorterTests: XCTestCase {
    /// Проверяет оба направления каждого доступного поля и правило пустых значений в конце.
    func testAllSortModesProduceExpectedOrder() {
        let tracks = [
            makeTrack(
                id: 1,
                title: "Beta",
                artist: "Alpha",
                album: "Zeta",
                year: 2000,
                genre: "Rock",
                dateAdded: Date(timeIntervalSince1970: 100)
            ),
            makeTrack(
                id: 2,
                title: "Alpha",
                artist: "Beta",
                album: "Alpha",
                year: 2020,
                genre: "Jazz",
                dateAdded: Date(timeIntervalSince1970: 200)
            ),
            makeTrack(
                id: 3,
                title: "Gamma",
                artist: nil,
                album: nil,
                year: nil,
                genre: nil,
                dateAdded: Date(timeIntervalSince1970: 50)
            )
        ]

        let expectedIdsByMode: [PurchasedITunesTrackSortMode: [UInt64]] = [
            .artistAsc: [1, 2, 3],
            .artistDesc: [2, 1, 3],
            .titleAsc: [2, 1, 3],
            .titleDesc: [3, 1, 2],
            .albumAsc: [2, 1, 3],
            .albumDesc: [1, 2, 3],
            .yearDesc: [2, 1, 3],
            .yearAsc: [1, 2, 3],
            .genreAsc: [2, 1, 3],
            .genreDesc: [1, 2, 3],
            .dateAddedDesc: [2, 1, 3],
            .dateAddedAsc: [3, 1, 2]
        ]

        for mode in PurchasedITunesTrackSortMode.allCases {
            XCTAssertEqual(
                PurchasedITunesTrackSorter.sort(tracks, mode: mode).map(\.id),
                expectedIdsByMode[mode],
                "Неверный порядок для режима \(mode.rawValue)"
            )
        }
    }

    /// Проверяет канонические запасные ключи и persistentID при равном основном поле.
    func testEqualPrimaryValuesUsePredictableFallbackOrder() {
        let tracks = [
            makeTrack(id: 30, title: "Same", artist: "Artist", album: "Album"),
            makeTrack(id: 10, title: "Beta", artist: "Artist", album: "Album"),
            makeTrack(id: 20, title: "Alpha", artist: "Artist", album: "Album"),
            makeTrack(id: 5, title: "Same", artist: "Artist", album: "Album")
        ]

        XCTAssertEqual(
            PurchasedITunesTrackSorter.sort(tracks, mode: .artistDesc).map(\.id),
            [20, 10, 5, 30]
        )
    }

    /// Проверяет, что пустая строка считается отсутствующим значением и не попадает в начало.
    func testBlankStringStaysAfterFilledValuesInBothDirections() {
        let tracks = [
            makeTrack(id: 1, title: "Blank", artist: "   "),
            makeTrack(id: 2, title: "Filled", artist: "Artist")
        ]

        XCTAssertEqual(
            PurchasedITunesTrackSorter.sort(tracks, mode: .artistAsc).map(\.id),
            [2, 1]
        )
        XCTAssertEqual(
            PurchasedITunesTrackSorter.sort(tracks, mode: .artistDesc).map(\.id),
            [2, 1]
        )
    }

    /// Проверяет полную локализованную подпись каждого режима родительского меню.
    func testEverySortModeHasExpectedPresentationTitle() {
        let expectedTitles: [PurchasedITunesTrackSortMode: String] = [
            .artistAsc: String(localized: "Artist A–Z"),
            .artistDesc: String(localized: "Artist Z–A"),
            .titleAsc: String(localized: "Title A–Z"),
            .titleDesc: String(localized: "Title Z–A"),
            .albumAsc: String(localized: "Album A–Z"),
            .albumDesc: String(localized: "Album Z–A"),
            .yearDesc: String(localized: "Year: Newest First"),
            .yearAsc: String(localized: "Year: Oldest First"),
            .genreAsc: String(localized: "Genre A–Z"),
            .genreDesc: String(localized: "Genre Z–A"),
            .dateAddedDesc: String(localized: "Date Added: Newest First"),
            .dateAddedAsc: String(localized: "Date Added: Oldest First")
        ]

        for mode in PurchasedITunesTrackSortMode.allCases {
            XCTAssertEqual(
                LibraryPresentationText.purchasedITunesTrackSortModeTitle(for: mode),
                expectedTitles[mode],
                "Неверная подпись для режима \(mode.rawValue)"
            )
        }
    }

    /// Создаёт минимальную runtime-модель без обращения к MediaPlayer.
    private func makeTrack(
        id: UInt64,
        title: String,
        artist: String? = nil,
        album: String? = nil,
        year: Int? = nil,
        genre: String? = nil,
        dateAdded: Date = Date(timeIntervalSince1970: 0)
    ) -> PurchasedITunesTrack {
        PurchasedITunesTrack(
            id: id,
            title: title,
            artist: artist,
            album: album,
            year: year,
            genre: genre,
            dateAdded: dateAdded,
            artworkData: nil,
            duration: 0,
            assetURL: URL(fileURLWithPath: "/tmp/purchased-\(id).m4a")
        )
    }
}

@MainActor
final class PurchasedITunesMusicViewModelTests: XCTestCase {
    /// Загрузчик контекста использует тот же сохранённый режим и сортировщик, что и экран «Куплено в iTunes».
    func testPlaybackContextLoaderUsesSavedSortMode() async {
        let provider = PurchasedITunesMusicProviderStub(
            tracks: [
                makeTrack(id: 1, title: "Beta", artist: "Artist"),
                makeTrack(id: 2, title: "Alpha", artist: "Artist")
            ]
        )
        let persistence = PurchasedITunesSortModePersistenceStub(mode: .titleAsc)
        let loader = PurchasedITunesPlaybackContextLoader(
            provider: provider,
            sortModePersistence: persistence
        )

        let result = await loader.loadPlaybackContext()

        guard case .loaded(let tracks) = result else {
            return XCTFail("Ожидался загруженный iTunes-контекст")
        }

        XCTAssertEqual(tracks.map(\.title), ["Alpha", "Beta"])
    }

    /// Проверяет, что смена режима пересортировывает кэш и не вызывает provider повторно.
    func testSelectSortModeReusesLoadedTracksAndPersistsSelection() async {
        let provider = PurchasedITunesMusicProviderStub(
            tracks: [
                makeTrack(id: 1, title: "Beta", artist: "Beta"),
                makeTrack(id: 2, title: "Alpha", artist: "Alpha")
            ]
        )
        let persistence = PurchasedITunesSortModePersistenceStub(mode: .titleAsc)
        let viewModel = PurchasedITunesMusicViewModel(
            provider: provider,
            sortModePersistence: persistence,
            favoriteTrackIdsProvider: PurchasedITunesFavoriteTrackIdsProviderStub(),
            playbackStateProvider: PurchasedITunesPlaybackStateProviderStub(),
            presenter: PurchasedITunesPresenter(
                artworkBadgeStateFactory: TrackArtworkBadgeStateFactory()
            )
        )

        await viewModel.load()
        XCTAssertEqual(loadedTitles(from: viewModel.screenState), ["Alpha", "Beta"])

        viewModel.selectSortMode(.artistDesc)

        XCTAssertEqual(loadedTitles(from: viewModel.screenState), ["Beta", "Alpha"])
        XCTAssertEqual(provider.loadTracksCallCount, 1)
        XCTAssertEqual(persistence.mode, .artistDesc)
        XCTAssertEqual(persistence.saveCallCount, 1)
    }

    /// Проверяет подготовку пустого состояния после разрешённого запроса без треков.
    func testLoadPresentsEmptyStateForAuthorizedEmptyLibrary() async {
        let viewModel = makeViewModel(
            provider: PurchasedITunesMusicProviderStub(tracks: [])
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.screenState.content, .empty)
        XCTAssertFalse(viewModel.screenState.canExport)
    }

    /// Проверяет, что запрет доступа не обращается к чтению медиатеки.
    func testLoadPresentsDeniedStateWithoutReadingTracks() async {
        let provider = PurchasedITunesMusicProviderStub(
            tracks: [],
            requestedAccessState: .denied
        )
        let viewModel = makeViewModel(provider: provider)

        await viewModel.load()

        XCTAssertEqual(viewModel.screenState.content, .denied)
        XCTAssertEqual(provider.loadTracksCallCount, 0)
    }

    /// Проверяет возврат видимого режима и порядка, если SQLite отклонил сохранение.
    func testSelectSortModeRestoresPreviousStateWhenPersistenceFails() async {
        let provider = PurchasedITunesMusicProviderStub(
            tracks: [
                makeTrack(id: 1, title: "Beta", artist: "Beta"),
                makeTrack(id: 2, title: "Alpha", artist: "Alpha")
            ]
        )
        let persistence = PurchasedITunesSortModePersistenceStub(
            mode: .titleAsc,
            shouldFailOnSave: true
        )
        let viewModel = makeViewModel(
            provider: provider,
            persistence: persistence
        )

        await viewModel.load()
        viewModel.selectSortMode(.artistDesc)

        XCTAssertEqual(viewModel.screenState.sortMode, .titleAsc)
        XCTAssertEqual(loadedTitles(from: viewModel.screenState), ["Alpha", "Beta"])
        XCTAssertEqual(persistence.mode, .titleAsc)
        XCTAssertEqual(persistence.saveCallCount, 1)
    }

    /// Собирает feature ViewModel с явными runtime-провайдерами для изолированной проверки.
    private func makeViewModel(
        provider: PurchasedITunesMusicProviderStub,
        persistence: PurchasedITunesSortModePersistenceStub? = nil
    ) -> PurchasedITunesMusicViewModel {
        let resolvedPersistence = persistence ?? PurchasedITunesSortModePersistenceStub(
            mode: .titleAsc
        )

        return PurchasedITunesMusicViewModel(
            provider: provider,
            sortModePersistence: resolvedPersistence,
            favoriteTrackIdsProvider: PurchasedITunesFavoriteTrackIdsProviderStub(),
            playbackStateProvider: PurchasedITunesPlaybackStateProviderStub(),
            presenter: PurchasedITunesPresenter(
                artworkBadgeStateFactory: TrackArtworkBadgeStateFactory()
            )
        )
    }

    /// Извлекает отображаемые заголовки только из готового screen-состояния.
    private func loadedTitles(
        from state: PurchasedITunesScreenState
    ) -> [String]? {
        guard case .loaded = state.content else {
            return nil
        }
        return state.tracks.map { $0.title ?? "" }
    }

    /// Создаёт минимальную runtime-модель для проверки ViewModel.
    private func makeTrack(
        id: UInt64,
        title: String,
        artist: String?
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
            duration: 0,
            assetURL: URL(fileURLWithPath: "/tmp/view-model-\(id).m4a")
        )
    }
}

/// Stub фиксирует количество чтений системной медиатеки.
private final class PurchasedITunesMusicProviderStub: PurchasedITunesMusicProviding {
    let tracks: [PurchasedITunesTrack]
    let requestedAccessState: PurchasedITunesMusicAccessState
    private(set) var loadTracksCallCount = 0

    init(
        tracks: [PurchasedITunesTrack],
        requestedAccessState: PurchasedITunesMusicAccessState = .authorized
    ) {
        self.tracks = tracks
        self.requestedAccessState = requestedAccessState
    }

    func accessState() -> PurchasedITunesMusicAccessState {
        requestedAccessState
    }

    func requestAccessIfNeeded() async -> PurchasedITunesMusicAccessState {
        requestedAccessState
    }

    func loadTracks() -> [PurchasedITunesTrack] {
        loadTracksCallCount += 1
        return tracks
    }
}

/// Stub сохраняет последний режим без SQLite для изолированной проверки ViewModel.
@MainActor
private final class PurchasedITunesSortModePersistenceStub: PurchasedITunesTrackSortModePersisting {
    var mode: PurchasedITunesTrackSortMode
    let shouldFailOnSave: Bool
    private(set) var saveCallCount = 0

    var purchasedITunesTrackSortMode: PurchasedITunesTrackSortMode {
        mode
    }

    init(
        mode: PurchasedITunesTrackSortMode,
        shouldFailOnSave: Bool = false
    ) {
        self.mode = mode
        self.shouldFailOnSave = shouldFailOnSave
    }

    func setPurchasedITunesTrackSortMode(_ mode: PurchasedITunesTrackSortMode) throws {
        saveCallCount += 1
        guard shouldFailOnSave == false else {
            throw PurchasedITunesSortModePersistenceError.failed
        }
        self.mode = mode
    }
}

/// Ошибка памяти позволяет проверить откат состояния без SQLite.
private enum PurchasedITunesSortModePersistenceError: Error {
    case failed
}

/// Публикует подтверждённые favorite-ID для feature ViewModel без PlayerViewModel.
@MainActor
private final class PurchasedITunesFavoriteTrackIdsProviderStub: FavoriteTrackIdsProviding {
    private let subject = CurrentValueSubject<Set<UUID>, Never>([])

    var favoriteTrackIds: Set<UUID> {
        subject.value
    }

    var favoriteTrackIdsPublisher: AnyPublisher<Set<UUID>, Never> {
        subject.eraseToAnyPublisher()
    }
}

/// Публикует минимальный playback-снимок для чистых тестов presentation-состояния.
@MainActor
private final class PurchasedITunesPlaybackStateProviderStub: PlaybackStateProviding {
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

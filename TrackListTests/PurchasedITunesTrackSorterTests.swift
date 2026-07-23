//
//  PurchasedITunesTrackSorterTests.swift
//  TrackListTests
//
//  Проверки сортировки и повторного использования загруженных iTunes-треков.
//
//  Created by Pavel Fomin on 23.07.2026.
//

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
            sortModePersistence: persistence
        )

        await viewModel.load()
        XCTAssertEqual(loadedIds(from: viewModel.state), [2, 1])

        viewModel.selectSortMode(.artistDesc)

        XCTAssertEqual(loadedIds(from: viewModel.state), [1, 2])
        XCTAssertEqual(provider.loadTracksCallCount, 1)
        XCTAssertEqual(persistence.mode, .artistDesc)
        XCTAssertEqual(persistence.saveCallCount, 1)
    }

    /// Извлекает идентификаторы только из готового loaded-состояния.
    private func loadedIds(
        from state: PurchasedITunesMusicViewModel.State
    ) -> [UInt64]? {
        guard case .loaded(let tracks) = state else {
            return nil
        }
        return tracks.map(\.id)
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
    private(set) var loadTracksCallCount = 0

    init(tracks: [PurchasedITunesTrack]) {
        self.tracks = tracks
    }

    func requestAccessIfNeeded() async -> PurchasedITunesMusicAccessState {
        .authorized
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
    private(set) var saveCallCount = 0

    var purchasedITunesTrackSortMode: PurchasedITunesTrackSortMode {
        mode
    }

    init(mode: PurchasedITunesTrackSortMode) {
        self.mode = mode
    }

    func setPurchasedITunesTrackSortMode(_ mode: PurchasedITunesTrackSortMode) throws {
        self.mode = mode
        saveCallCount += 1
    }
}

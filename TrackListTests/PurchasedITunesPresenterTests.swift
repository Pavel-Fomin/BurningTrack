//
//  PurchasedITunesPresenterTests.swift
//  TrackListTests
//
//  Проверки подготовки состояния экрана «Куплено в iTunes».
//
//  Created by Pavel Fomin on 11.08.2026.
//

import Foundation
import XCTest
@testable import TrackList

@MainActor
final class PurchasedITunesPresenterTests: XCTestCase {

    /// Проверяет подготовку полной строки без вычислений favorite и playback во View.
    func testLoadedContentPreparesRowsPlaybackAndFavoriteState() {
        let sourceTrack = makeTrack(id: 42, title: "Track", artist: nil)
        let playableTrack = PurchasedITunesPlayableTrack(track: sourceTrack)
        let presenter = PurchasedITunesPresenter(
            artworkBadgeStateFactory: TrackArtworkBadgeStateFactory()
        )

        let state = presenter.present(
            content: .loaded([sourceTrack]),
            sortMode: .artistAsc,
            favoriteTrackIds: [playableTrack.trackId],
            playbackState: PlaybackStateSnapshot(
                currentDisplayableId: playableTrack.id,
                currentTrackId: playableTrack.trackId,
                currentContext: .purchasedITunes,
                currentContextSource: .purchasedITunes,
                isPlaying: true
            )
        )

        guard case .loaded(let rows) = state.content,
              let row = rows.first
        else {
            return XCTFail("Ожидалась готовая строка iTunes")
        }

        XCTAssertEqual(state.sortMode, .artistAsc)
        XCTAssertTrue(state.canExport)
        XCTAssertEqual(state.tracks, [playableTrack])
        XCTAssertEqual(row.track, playableTrack)
        XCTAssertEqual(row.artist, String(localized: "Unknown Artist"))
        XCTAssertEqual(row.duration, 1)
        XCTAssertEqual(row.artworkRequest.trackId, playableTrack.trackId)
        XCTAssertEqual(row.artworkRequest.purpose, .trackList)
        XCTAssertTrue(row.isFavorite)
        XCTAssertTrue(row.isCurrent)
        XCTAssertTrue(row.isPlaying)
        XCTAssertEqual(
            row.artworkBadgeState,
            .source(.apple, isFavorite: true)
        )
    }

    /// Проверяет, что denied-состояние не оставляет строки или возможность экспорта.
    func testDeniedContentHasNoRowsOrExport() {
        let state = PurchasedITunesPresenter(
            artworkBadgeStateFactory: TrackArtworkBadgeStateFactory()
        )
        .present(
            content: .denied,
            sortMode: .dateAddedDesc,
            favoriteTrackIds: [],
            playbackState: PlaybackStateSnapshot(
                currentDisplayableId: nil,
                currentTrackId: nil,
                currentContext: nil,
                currentContextSource: nil,
                isPlaying: false
            )
        )

        XCTAssertEqual(state.content, .denied)
        XCTAssertFalse(state.canExport)
        XCTAssertTrue(state.tracks.isEmpty)
    }

    /// Проверяет, что промежуточное и пустое content-состояния не содержат данных для строк или экспорта.
    func testLoadingAndEmptyContentHaveNoRowsOrExport() {
        let presenter = PurchasedITunesPresenter(
            artworkBadgeStateFactory: TrackArtworkBadgeStateFactory()
        )
        let playbackState = PlaybackStateSnapshot(
            currentDisplayableId: nil,
            currentTrackId: nil,
            currentContext: nil,
            currentContextSource: nil,
            isPlaying: false
        )

        let loadingState = presenter.present(
            content: .loading,
            sortMode: .titleAsc,
            favoriteTrackIds: [],
            playbackState: playbackState
        )
        let emptyState = presenter.present(
            content: .empty,
            sortMode: .titleAsc,
            favoriteTrackIds: [],
            playbackState: playbackState
        )

        XCTAssertEqual(loadingState.content, .loading)
        XCTAssertFalse(loadingState.canExport)
        XCTAssertTrue(loadingState.tracks.isEmpty)
        XCTAssertEqual(emptyState.content, .empty)
        XCTAssertFalse(emptyState.canExport)
        XCTAssertTrue(emptyState.tracks.isEmpty)
    }

    /// Проверяет, что совпадающий ID вне iTunes-контекста не подсвечивает строку.
    func testNonPurchasedPlaybackContextDoesNotMarkRowAsCurrent() {
        let sourceTrack = makeTrack(id: 7, title: "Track", artist: "Artist")
        let playableTrack = PurchasedITunesPlayableTrack(track: sourceTrack)
        let state = PurchasedITunesPresenter(
            artworkBadgeStateFactory: TrackArtworkBadgeStateFactory()
        )
        .present(
            content: .loaded([sourceTrack]),
            sortMode: .titleAsc,
            favoriteTrackIds: [],
            playbackState: PlaybackStateSnapshot(
                currentDisplayableId: playableTrack.id,
                currentTrackId: playableTrack.trackId,
                currentContext: .library,
                currentContextSource: .libraryRoot,
                isPlaying: true
            )
        )

        guard case .loaded(let rows) = state.content,
              let row = rows.first
        else {
            return XCTFail("Ожидалась готовая строка iTunes")
        }

        XCTAssertFalse(row.isCurrent)
        XCTAssertFalse(row.isPlaying)
    }

    /// Создаёт устойчивую runtime-модель без обращения к MediaPlayer.
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
            duration: 1,
            assetURL: URL(fileURLWithPath: "/tmp/presenter-\(id).m4a")
        )
    }
}

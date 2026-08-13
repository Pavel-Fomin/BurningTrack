//
//  TrackArtworkBadgeStateFactoryTests.swift
//  TrackList
//
//  Проверки фабрики presentation-состояния бейджа обложки.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import XCTest
@testable import TrackList

final class TrackArtworkBadgeStateFactoryTests: XCTestCase {

    /// Обычный локальный трек без «Избранного» не получает бейдж.
    func testLibraryTrackWithoutFavoriteProducesHiddenState() {
        let state = TrackArtworkBadgeStateFactory().makeState(
            source: .library,
            isFavorite: false
        )

        XCTAssertEqual(state, .hidden)
    }

    /// Локальный трек в «Избранном» получает отдельный символ сердца.
    func testFavoriteLibraryTrackProducesFavoriteState() {
        let state = TrackArtworkBadgeStateFactory().makeState(
            source: .library,
            isFavorite: true
        )

        XCTAssertEqual(state, .favorite)
    }

    /// Внешний iTunes-трек сохраняет логотип Apple без состояния «Избранного».
    func testPurchasedITunesTrackWithoutFavoriteProducesAppleSourceState() {
        let state = TrackArtworkBadgeStateFactory().makeState(
            source: .purchasedITunes,
            isFavorite: false
        )

        XCTAssertEqual(state, .source(.apple, isFavorite: false))
    }

    /// Внешний iTunes-трек передаёт «Избранное» как состояние Apple-бейджа.
    func testFavoritePurchasedITunesTrackProducesFavoriteAppleSourceState() {
        let state = TrackArtworkBadgeStateFactory().makeState(
            source: .purchasedITunes,
            isFavorite: true
        )

        XCTAssertEqual(state, .source(.apple, isFavorite: true))
    }

    /// Builder очереди сохраняет типизированный источник iTunes и состояние «Избранного».
    @MainActor
    func testPlayerRowBuilderPreservesPurchasedITunesFavoriteBadge() {
        let trackId = UUID()
        let track = PlayerTrack(
            trackId: trackId,
            title: "Song",
            artist: "Artist",
            duration: 180,
            fileName: "song.m4a",
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: URL(fileURLWithPath: "/tmp/song.m4a")
        )

        let rows = PlayerTrackRowStateBuilder().makeRows(
            tracks: [track],
            currentQueueItemId: nil,
            isPlaying: false,
            favoriteTrackIds: [trackId],
            snapshotsByTrackId: [:],
            collectionNavigationTargetsByTrackId: [:],
            highlightedRowId: nil,
            shouldShowTags: true,
            shouldShowFileFormat: true
        )

        XCTAssertEqual(rows.first?.artworkBadgeState, .source(.apple, isFavorite: true))
    }

    /// Builder треклиста передаёт source в общую фабрику, не определяя его по метаданным файла.
    @MainActor
    func testTrackListRowBuilderPreservesPurchasedITunesFavoriteBadge() {
        let trackId = UUID()
        let track = Track(
            trackId: trackId,
            title: "Song",
            artist: "Artist",
            artworkData: nil,
            duration: 180,
            fileName: "song.m4a",
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: URL(fileURLWithPath: "/tmp/song.m4a")
        )

        let row = TrackListRowStateBuilder().build(
            track: track,
            snapshot: nil,
            isCurrent: false,
            isPlaying: false,
            isHighlighted: false,
            isFavorite: true,
            settings: .defaultValue,
            collectionNavigationTarget: nil
        )

        XCTAssertEqual(row.artworkBadgeState, .source(.apple, isFavorite: true))
    }
}

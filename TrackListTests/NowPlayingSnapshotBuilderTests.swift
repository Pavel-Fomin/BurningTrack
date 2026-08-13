//
// "NowPlayingSnapshotBuilderTests.swift"
// TrackList
// Проверяет чистый контракт формирования Now Playing snapshot.
// Created by Pavel Fomin on 13.08.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class NowPlayingSnapshotBuilderTests: XCTestCase {
    func testShowsRuntimeTagsWhenEnabled() {
        let track = makeLocalTrack()
        let snapshot = makeRuntimeSnapshot(trackId: track.trackId)

        let result = makeBuilder().makeSnapshot(
            track: track,
            runtimeSnapshot: snapshot,
            artwork: nil,
            currentTime: 12,
            fallbackDuration: 100,
            isPlaying: true,
            shouldShowTags: true
        )

        XCTAssertEqual(result.title, "Runtime title")
        XCTAssertEqual(result.artist, "Runtime artist")
        XCTAssertEqual(result.album, "Runtime album")
        XCTAssertEqual(result.duration, 180)
    }

    func testHidesRuntimeTagsWhenDisabled() {
        let track = makeLocalTrack()
        let snapshot = makeRuntimeSnapshot(trackId: track.trackId)

        let result = makeBuilder().makeSnapshot(
            track: track,
            runtimeSnapshot: snapshot,
            artwork: nil,
            currentTime: 12,
            fallbackDuration: 100,
            isPlaying: true,
            shouldShowTags: false
        )

        XCTAssertEqual(result.title, track.fileName)
        XCTAssertEqual(result.artist, "")
        XCTAssertNil(result.album)
        XCTAssertNil(result.artwork)
    }

    func testPurchasedITunesBranchKeepsMediaPlayerMetadataWhenTagsDisabled() {
        let track = PlayerTrack(
            trackId: UUID(),
            title: "Purchased title",
            artist: "Purchased artist",
            album: "Purchased album",
            duration: 210,
            fileName: "Purchased.m4a",
            isAvailable: true,
            source: .purchasedITunes,
            assetURL: URL(fileURLWithPath: "/tmp/purchased.m4a")
        )

        let result = makeBuilder().makeSnapshot(
            track: track,
            runtimeSnapshot: nil,
            artwork: nil,
            currentTime: 4,
            fallbackDuration: 100,
            isPlaying: false,
            shouldShowTags: false
        )

        XCTAssertEqual(result.title, "Purchased title")
        XCTAssertEqual(result.artist, "Purchased artist")
        XCTAssertEqual(result.album, "Purchased album")
        XCTAssertEqual(result.duration, 210)
    }

    private func makeBuilder() -> NowPlayingSnapshotBuilder {
        NowPlayingSnapshotBuilder()
    }

    private func makeLocalTrack() -> PlayerTrack {
        PlayerTrack(
            trackId: UUID(),
            title: "Stored title",
            artist: "Stored artist",
            duration: 100,
            fileName: "Stored.m4a",
            isAvailable: true
        )
    }

    private func makeRuntimeSnapshot(trackId: UUID) -> TrackRuntimeSnapshot {
        TrackRuntimeSnapshot(
            trackId: trackId,
            fileName: "Runtime.m4a",
            isAvailable: true,
            technicalMetadata: TrackTechnicalMetadata(
                fileSizeBytes: nil,
                fileFormat: "M4A",
                bitrateBitsPerSecond: nil
            ),
            title: "Runtime title",
            artist: "Runtime artist",
            album: "Runtime album",
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
            duration: 180,
            artworkData: nil,
            artworkSourceIdentifier: nil,
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

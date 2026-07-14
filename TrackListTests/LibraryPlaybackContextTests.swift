//
//  LibraryPlaybackContextTests.swift
//  TrackListTests
//
//  Тесты загрузки и порядка playback-контекстов фонотеки.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import XCTest
@testable import TrackList

@MainActor
final class LibraryPlaybackContextTests: XCTestCase {
    func testRootContextLoaderUsesLibraryTrackOrder() async throws {
        let oldest = makeTrack(
            id: UUID(),
            fileName: "oldest.mp3",
            date: Date(timeIntervalSince1970: 100)
        )
        let newest = makeTrack(
            id: UUID(),
            fileName: "newest.mp3",
            date: Date(timeIntervalSince1970: 300)
        )
        let middle = makeTrack(
            id: UUID(),
            fileName: "middle.mp3",
            date: Date(timeIntervalSince1970: 200)
        )
        let loader = LibraryPlaybackContextLoader(
            tracksProvider: StubLibraryTracksProvider(
                tracks: [oldest, middle, newest]
            )
        )

        let tracks = try await loader.loadRootContext()

        XCTAssertEqual(tracks.map(\.trackId), [newest.trackId, middle.trackId, oldest.trackId])
    }

    func testPlaybackContextSourceMappingPreservesLibrarySource() {
        let folderId = UUID()
        let sources: [PlaybackContextSource] = [
            .playerQueue,
            .trackList(id: UUID()),
            .libraryFolder(id: folderId),
            .libraryRoot
        ]

        for source in sources {
            let databaseType = PlaybackContextSourceDatabaseMapper.databaseType(from: source)
            let contextId = PlaybackContextSourceDatabaseMapper.contextId(from: source)
            let restored = PlaybackContextSourceDatabaseMapper.playbackSource(
                from: databaseType,
                contextId: contextId
            )

            XCTAssertEqual(restored, source)
        }

        XCTAssertNil(
            PlaybackContextSourceDatabaseMapper.playbackSource(
                from: .libraryFolder,
                contextId: nil
            )
        )
        XCTAssertNil(
            PlaybackContextSourceDatabaseMapper.playbackSource(
                from: .libraryRoot,
                contextId: folderId
            )
        )
    }

    /// Создаёт доступную модель фонотеки для проверки только порядка, без обращения к файловой системе.
    private func makeTrack(id: UUID, fileName: String, date: Date) -> LibraryTrack {
        LibraryTrack(
            id: id,
            fileURL: URL(fileURLWithPath: "/tmp/\(fileName)"),
            title: nil,
            artist: nil,
            duration: 10,
            addedDate: date,
            isAvailable: true
        )
    }
}

/// Возвращает подготовленный список, имитируя SQLite provider без изменения базы данных.
private struct StubLibraryTracksProvider: LibraryTracksProvider {
    let tracks: [LibraryTrack]

    func tracks(for source: LibraryTrackListSource) async -> [LibraryTrack] {
        tracks
    }
}

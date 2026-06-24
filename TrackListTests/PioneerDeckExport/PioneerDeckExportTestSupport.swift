//
//  PioneerDeckExportTestSupport.swift
//  TrackListTests
//
//  Общие фикстуры для readback/golden-тестов Pioneer Export.
//

import Foundation
import XCTest

#if canImport(BurningTrackPioneerDeckExport)
@testable import BurningTrackPioneerDeckExport
#else
@testable import TrackList
#endif

/// Тестовые helper-методы для writer-слоя Pioneer Export.
enum PioneerDeckExportTestSupport {
    /// Стабильные UUID трёх тестовых треков.
    static let sourceTrackIds = [
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
    ]

    /// Создаёт source-модель из двух плейлистов и трёх уникальных треков.
    static func makeSourcePlaylists(sourceURLs: [UUID: URL] = [:]) -> [PioneerDeckSourcePlaylist] {
        let firstId = sourceTrackIds[0]
        let secondId = sourceTrackIds[1]
        let thirdId = sourceTrackIds[2]
        let playlistAId = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let playlistBId = UUID(uuidString: "10000000-0000-0000-0000-000000000002")!

        let first = PioneerDeckSourceTrack(
            sourceTrackId: firstId,
            title: "First Track",
            artist: "Artist A",
            duration: 61,
            fileName: "first.m4a",
            sourceFileURL: sourceURLs[firstId]
        )
        let second = PioneerDeckSourceTrack(
            sourceTrackId: secondId,
            title: nil,
            artist: nil,
            duration: -10,
            fileName: "second.aiff",
            sourceFileURL: sourceURLs[secondId]
        )
        let third = PioneerDeckSourceTrack(
            sourceTrackId: thirdId,
            title: "Third Track",
            artist: "Artist C",
            duration: 123,
            fileName: "third.wav",
            sourceFileURL: sourceURLs[thirdId]
        )

        return [
            PioneerDeckSourcePlaylist(sourcePlaylistId: playlistAId, name: "Warmup", tracks: [first, second, third]),
            PioneerDeckSourcePlaylist(sourcePlaylistId: playlistBId, name: "Peak", tracks: [third, first])
        ]
    }

    /// Создаёт готовую export-модель.
    static func makeExport(sourceURLs: [UUID: URL] = [:]) throws -> PioneerDeckExport {
        try PioneerDeckExportFactory.makeExport(from: makeSourcePlaylists(sourceURLs: sourceURLs))
    }

    /// Создаёт source-модель одного плейлиста с порядком track_id 3, 1, 2.
    static func makeReorderedSourcePlaylists(sourceURLs: [UUID: URL] = [:]) -> [PioneerDeckSourcePlaylist] {
        let firstId = sourceTrackIds[0]
        let secondId = sourceTrackIds[1]
        let thirdId = sourceTrackIds[2]
        let playlistId = UUID(uuidString: "10000000-0000-0000-0000-000000000003")!

        let first = PioneerDeckSourceTrack(
            sourceTrackId: firstId,
            title: "First Track",
            artist: "Artist A",
            duration: 61,
            fileName: "first.m4a",
            sourceFileURL: sourceURLs[firstId]
        )
        let second = PioneerDeckSourceTrack(
            sourceTrackId: secondId,
            title: "Second Track",
            artist: "Artist B",
            duration: 92,
            fileName: "second.aiff",
            sourceFileURL: sourceURLs[secondId]
        )
        let third = PioneerDeckSourceTrack(
            sourceTrackId: thirdId,
            title: "Third Track",
            artist: "Artist C",
            duration: 123,
            fileName: "third.wav",
            sourceFileURL: sourceURLs[thirdId]
        )

        return [
            PioneerDeckSourcePlaylist(sourcePlaylistId: playlistId, name: "Reordered", tracks: [third, first, second])
        ]
    }

    /// Создаёт export-модель с порядком track_id 3, 1, 2 внутри одного плейлиста.
    static func makeReorderedExport(sourceURLs: [UUID: URL] = [:]) throws -> PioneerDeckExport {
        try PioneerDeckExportFactory.makeExport(from: makeReorderedSourcePlaylists(sourceURLs: sourceURLs))
    }

    /// Создаёт временную директорию теста.
    static func makeTemporaryDirectory(named name: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("BurningTrackPioneerDeckExportTests", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Создаёт стабильные аудио-файлы для golden-теста.
    static func makeAudioSources(in directory: URL) throws -> [UUID: URL] {
        let fileNames = ["first.m4a", "second.aiff", "third.wav"]

        return try Dictionary(uniqueKeysWithValues: zip(sourceTrackIds, fileNames).enumerated().map { index, pair in
            let (id, fileName) = pair
            let url = directory.appendingPathComponent(fileName)
            try Data(repeating: UInt8(index + 1), count: 16).write(to: url)
            return (id, url)
        })
    }

    /// Возвращает все файлы директории как relativePath -> Data.
    static func collectFiles(root: URL) throws -> [String: Data] {
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else {
            return [:]
        }

        var result: [String: Data] = [:]
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            let rootComponents = root.standardizedFileURL.pathComponents
            let fileComponents = url.standardizedFileURL.pathComponents
            let relativePath = fileComponents.dropFirst(rootComponents.count).joined(separator: "/")
            result[relativePath] = try Data(contentsOf: url)
        }
        return result
    }
}

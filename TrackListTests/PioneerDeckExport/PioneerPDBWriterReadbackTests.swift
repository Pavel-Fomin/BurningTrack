//
//  PioneerPDBWriterReadbackTests.swift
//  TrackListTests
//
//  Readback-тесты DeviceSQL export.pdb.
//

import XCTest

#if canImport(BurningTrackPioneerDeckExport)
@testable import BurningTrackPioneerDeckExport
#else
@testable import TrackList
#endif

final class PioneerPDBWriterReadbackTests: XCTestCase {
    /// Проверяет, что factory сохраняет уникальность треков и порядок entries.
    func testFactoryBuildsUniqueTracksAndPlaylistOrder() throws {
        let export = try PioneerDeckExportTestSupport.makeExport()

        XCTAssertEqual(export.tracks.count, 3)
        XCTAssertEqual(export.playlists.count, 2)
        XCTAssertEqual(export.playlists[0].entries.map(\.position), [1, 2, 3])
        XCTAssertEqual(export.playlists[1].entries.map(\.position), [1, 2])
        XCTAssertEqual(export.playlists[0].entries.map(\.trackId), [1, 2, 3])
        XCTAssertEqual(export.playlists[1].entries.map(\.trackId), [3, 1])
        XCTAssertEqual(export.tracks[1].title, "second")
        XCTAssertEqual(export.tracks[1].artist, "")
        XCTAssertEqual(export.tracks[1].durationSeconds, 0)
    }

    /// Проверяет, что factory заполняет file_size только по реальному sourceFileURL.
    func testFactoryFillsFileSizeFromSourceFileURL() throws {
        let directory = try PioneerDeckExportTestSupport.makeTemporaryDirectory(named: "FactoryFileSize")
        let sourceURLs = try PioneerDeckExportTestSupport.makeAudioSources(in: directory)
        let export = try PioneerDeckExportTestSupport.makeExport(sourceURLs: sourceURLs)

        XCTAssertEqual(export.tracks.map(\.fileSize), [UInt32?](repeating: 16, count: 3))
        XCTAssertEqual(export.tracks.map(\.sampleRate), [UInt32?](repeating: nil, count: 3))
        XCTAssertEqual(export.tracks.map(\.sampleDepth), [UInt16?](repeating: nil, count: 3))
        XCTAssertEqual(export.tracks.map(\.bitrate), [UInt32?](repeating: nil, count: 3))
        XCTAssertEqual(export.tracks.map(\.tempoX100), [UInt32?](repeating: nil, count: 3))
    }

    /// Проверяет DeviceSQL header и полный набор table descriptors.
    func testExportPDBDeviceSQLContainsRequiredTables() throws {
        let export = try PioneerDeckExportTestSupport.makeExport()
        let data = try PioneerPDBWriter().write(export: export)
        let readback = try PioneerDeviceSQLReadbackInspector.inspect(data: data)
        let expectedTableNames = Set(PioneerDeviceSQLTableType.allCases.map(\.tableName))

        XCTAssertEqual(readback.header.unknownSignature, 0)
        XCTAssertEqual(readback.header.pageSize, UInt32(PioneerPDBWriter.pageSize))
        XCTAssertEqual(readback.header.tableCount, UInt32(PioneerDeviceSQLTableType.allCases.count))
        XCTAssertEqual(readback.header.nextUnusedPage, 45)
        XCTAssertEqual(readback.header.unknown0x10, 1)
        XCTAssertEqual(data.count / PioneerPDBWriter.pageSize, Int(readback.header.nextUnusedPage))
        XCTAssertEqual(Set(readback.tables.keys), expectedTableNames)
        XCTAssertEqual(readback.tables["tracks"]?.type, PioneerDeviceSQLTableType.tracks.rawValue)
        XCTAssertEqual(readback.tables["colors"]?.type, PioneerDeviceSQLTableType.colors.rawValue)
        XCTAssertEqual(readback.tables["playlist_tree"]?.type, PioneerDeviceSQLTableType.playlistTree.rawValue)
        XCTAssertEqual(readback.tables["playlist_entries"]?.type, PioneerDeviceSQLTableType.playlistEntries.rawValue)
        XCTAssertEqual(readback.tables["tracks"]?.rows.count, 3)
        XCTAssertEqual(readback.tables["playlist_tree"]?.rows.count, 2)
        XCTAssertEqual(readback.tables["playlist_entries"]?.rows.count, 5)
        XCTAssertEqual(readback.tables["colors"]?.rows.count, 8)
        XCTAssertEqual(readback.tables["genres"]?.rows.count, 0)
        XCTAssertEqual(readback.tables["artists"]?.rows.count, 0)
        XCTAssertEqual(readback.tables["albums"]?.rows.count, 0)
        XCTAssertEqual(readback.tables["columns"]?.rows.count, 0)
        XCTAssertEqual(readback.tables["history"]?.rows.count, 0)
        XCTAssertTrue(readback.tables.values.allSatisfy { $0.emptyCandidate > 0 })
        XCTAssertTrue(readback.tables.values.allSatisfy { $0.emptyCandidate < readback.header.nextUnusedPage })
        XCTAssertTrue(readback.tables.values.allSatisfy { $0.pages.last?.nextPage == $0.emptyCandidate })
        XCTAssertEqual(readback.tables["tracks"]?.pages.last?.pageFlags, 0x34)
    }

    /// Проверяет, что playlist_entries читаются обратно в порядке entry_index.
    func testPlaylistEntriesPreserveTrackOrder() throws {
        let export = try PioneerDeckExportTestSupport.makeExport()
        let data = try PioneerPDBWriter().write(export: export)
        let readback = try PioneerDeviceSQLReadbackInspector.inspect(data: data)

        XCTAssertEqual(
            readback.playlistEntriesInPlaylistOrder,
            [
                PioneerDeviceSQLReadbackPlaylistEntry(entryIndex: 1, trackId: 1, playlistId: 1),
                PioneerDeviceSQLReadbackPlaylistEntry(entryIndex: 2, trackId: 2, playlistId: 1),
                PioneerDeviceSQLReadbackPlaylistEntry(entryIndex: 3, trackId: 3, playlistId: 1),
                PioneerDeviceSQLReadbackPlaylistEntry(entryIndex: 1, trackId: 3, playlistId: 2),
                PioneerDeviceSQLReadbackPlaylistEntry(entryIndex: 2, trackId: 1, playlistId: 2)
            ]
        )
    }

    /// Проверяет, что порядок 3, 1, 2 не сводится к сортировке по track_id.
    func testPlaylistEntriesPreserveNonNaturalTrackOrderByEntryIndex() throws {
        let export = try PioneerDeckExportTestSupport.makeReorderedExport()
        let data = try PioneerPDBWriter().write(export: export)
        let readback = try PioneerDeviceSQLReadbackInspector.inspect(data: data)

        XCTAssertEqual(export.playlists[0].entries.map(\.trackId), [3, 1, 2])
        XCTAssertEqual(export.playlists[0].entries.map(\.position), [1, 2, 3])
        XCTAssertEqual(
            readback.playlistEntriesInPlaylistOrder,
            [
                PioneerDeviceSQLReadbackPlaylistEntry(entryIndex: 1, trackId: 3, playlistId: 1),
                PioneerDeviceSQLReadbackPlaylistEntry(entryIndex: 2, trackId: 1, playlistId: 1),
                PioneerDeviceSQLReadbackPlaylistEntry(entryIndex: 3, trackId: 2, playlistId: 1)
            ]
        )
    }

    /// Проверяет, что readback видит реальные строки tracks и playlist_tree.
    func testDeviceSQLReadbackSeesPlaylistsAndTracks() throws {
        let export = try PioneerDeckExportTestSupport.makeExport()
        let data = try PioneerPDBWriter().write(export: export)
        let readback = try PioneerDeviceSQLReadbackInspector.inspect(data: data)

        XCTAssertEqual(readback.tables["tracks"]?.tracks.map(\.id), [1, 2, 3])
        XCTAssertEqual(readback.tables["tracks"]?.tracks.map(\.title), ["First Track", "second", "Third Track"])
        XCTAssertEqual(readback.tables["playlist_tree"]?.playlists.map(\.name), ["Warmup", "Peak"])
        XCTAssertEqual(readback.tables["playlist_tree"]?.playlists.map(\.sortOrder), [0, 0])
    }

    /// Проверяет диагностику декодированных полей playlist_tree_row.
    func testStructuralDumpDecodesPlaylistTreeFields() throws {
        let export = try PioneerDeckExportTestSupport.makeReorderedExport()
        let data = try PioneerPDBWriter().write(export: export)
        let dump = try PioneerDeviceSQLStructuralDumpBuilder.inspect(data: data)
        let playlistTree = try XCTUnwrap(dump.tables.first { $0.name == "playlist_tree" })
        let row = try XCTUnwrap(playlistTree.pages.flatMap(\.presentRows).first?.decoded)

        XCTAssertEqual(row.kind, "playlist_tree")
        XCTAssertEqual(row.id, 1)
        XCTAssertEqual(row.fields["parent_id"], "0")
        XCTAssertEqual(row.fields["unknown_0x04_hex"], "00000000")
        XCTAssertEqual(row.fields["sort_order"], "0")
        XCTAssertEqual(row.fields["raw_is_folder"], "0")
        XCTAssertEqual(row.fields["is_folder"], "false")
        XCTAssertEqual(row.fields["name"], "Reordered")
        XCTAssertEqual(row.fields["string_encoded_size"], "10")
        XCTAssertEqual(row.fields["padding_size"], "2")
        XCTAssertEqual(row.fields["padding_hex"], "0000")
        XCTAssertEqual(row.fields["row_size"], "32")
    }

    /// Проверяет диагностику декодированных полей color_row.
    func testStructuralDumpDecodesColorFields() throws {
        let export = try PioneerDeckExportTestSupport.makeExport()
        let data = try PioneerPDBWriter().write(export: export)
        let dump = try PioneerDeviceSQLStructuralDumpBuilder.inspect(data: data)
        let colors = try XCTUnwrap(dump.tables.first { $0.name == "colors" })
        let rows = colors.pages
            .flatMap(\.presentRows)
            .compactMap(\.decoded)
            .sorted { ($0.id ?? 0) < ($1.id ?? 0) }

        XCTAssertEqual(rows.count, 8)
        XCTAssertEqual(Set(colors.pages.flatMap(\.presentRows).compactMap(\.estimatedRowSize)), [12, 16])
        XCTAssertEqual(rows.map { $0.id ?? 0 }, Array(1...8).map(UInt32.init))
        XCTAssertEqual(rows.map { $0.fields["name"] }, ["Pink", "Red", "Orange", "Yellow", "Green", "Aqua", "Blue", "Purple"])
        XCTAssertEqual(rows.map { $0.fields["unknown_0x00_hex"] }, Array(repeating: "00000000", count: 8))
        XCTAssertEqual(rows.map { $0.fields["unknown_0x04"] }, Array(1...8).map(String.init))
        XCTAssertEqual(rows.map { $0.fields["unknown_0x07"] }, Array(repeating: "0", count: 8))
        XCTAssertEqual(rows[0].fields["padding_size"], "3")
        XCTAssertEqual(rows[1].fields["padding_size"], "0")
        XCTAssertEqual(rows[0].fields["padding_hex"], "000000")
    }

    /// Проверяет диагностику декодированных полей track_row.
    func testStructuralDumpDecodesTrackFields() throws {
        let export = try PioneerDeckExportTestSupport.makeExport()
        let data = try PioneerPDBWriter().write(export: export)
        let dump = try PioneerDeviceSQLStructuralDumpBuilder.inspect(data: data)
        let tracks = try XCTUnwrap(dump.tables.first { $0.name == "tracks" })
        let rows = tracks.pages
            .flatMap(\.presentRows)
            .compactMap(\.decoded)
            .sorted { ($0.id ?? 0) < ($1.id ?? 0) }
        let row = try XCTUnwrap(rows.first)

        XCTAssertEqual(row.kind, "track")
        XCTAssertEqual(row.id, 1)
        XCTAssertEqual(row.fields["subtype"], "0x0024")
        XCTAssertEqual(row.fields["sample_rate"], "0")
        XCTAssertEqual(row.fields["file_size"], "0")
        XCTAssertEqual(row.fields["track_id"], "1")
        XCTAssertEqual(row.fields["row_index"], "0")
        XCTAssertEqual(row.fields["index_shift_offset"], "0x02")
        XCTAssertEqual(row.fields["index_shift_raw_hex"], "0000")
        XCTAssertEqual(row.fields["bitmask_offset"], "0x04")
        XCTAssertEqual(row.fields["bitmask_raw_hex"], "00000000")
        XCTAssertEqual(row.fields["duration"], "61")
        XCTAssertEqual(row.fields["unknown_0x18"], "19048")
        XCTAssertEqual(row.fields["unknown_0x18_offset"], "0x18")
        XCTAssertEqual(row.fields["unknown_0x18_raw_hex"], "684a")
        XCTAssertEqual(row.fields["unknown_0x1a"], "30967")
        XCTAssertEqual(row.fields["unknown_0x1a_offset"], "0x1a")
        XCTAssertEqual(row.fields["unknown_0x1a_raw_hex"], "f778")
        XCTAssertEqual(row.fields["unknown_0x56"], "41")
        XCTAssertEqual(row.fields["unknown_0x5a"], "1")
        XCTAssertEqual(row.fields["unknown_0x5a_offset"], "0x5a")
        XCTAssertEqual(row.fields["unknown_0x5a_raw_hex"], "0100")
        XCTAssertEqual(row.fields["unknown_0x5c"], "3")
        XCTAssertEqual(row.fields["title"], "First Track")
        XCTAssertEqual(row.fields["filename"], "first.m4a")
        XCTAssertEqual(row.fields["file_path"], "/Contents/Artist A/UnknownAlbum/first.m4a")
        XCTAssertEqual(row.fields["analyze_path"], "/PIONEER/USBANLZ/P001/00000001/ANLZ0000.DAT")
        XCTAssertEqual(row.fields["kuvo_public"], "ON")
        XCTAssertEqual(row.fields["kuvo_public_kind"], "0x07")
        XCTAssertEqual(row.fields["kuvo_public_encoded_size"], "3")
        XCTAssertEqual(row.fields["autoload_hot_cues"], "ON")
        XCTAssertEqual(row.fields["autoload_hot_cues_kind"], "0x07")
        XCTAssertEqual(row.fields["autoload_hot_cues_encoded_size"], "3")
        XCTAssertEqual(row.fields["analyze_date"], "")
        XCTAssertEqual(row.fields["isrc_encoded_size"], "1")
        XCTAssertEqual(row.fields["title_encoded_size"], "12")
        XCTAssertEqual(row.fields["row_size"], "265")
    }

    /// Проверяет, что track_row пишет подтверждённые technical audio/file и string-поля из модели.
    func testTrackRowWritesTechnicalAudioFields() throws {
        let sourceTrackId = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let sourcePlaylistId = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
        let track = PioneerDeckTrack(
            id: 1,
            sourceTrackId: sourceTrackId,
            title: "Technical Track",
            artist: "Artist",
            durationSeconds: 180,
            sampleRate: 48_000,
            fileSize: 123_456,
            sampleDepth: 24,
            bitrate: 320_000,
            tempoX100: 12_850,
            analyzeDate: "2026-06-23",
            fileName: "technical.wav",
            usbRelativePath: "/Contents/Artist/UnknownAlbum/technical.wav",
            colorId: 0
        )
        let playlist = PioneerDeckPlaylist(
            id: 1,
            sourcePlaylistId: sourcePlaylistId,
            name: "Technical",
            entries: [PioneerDeckPlaylistEntry(trackId: 1, position: 1)]
        )
        let export = PioneerDeckExport(playlists: [playlist], tracks: [track])
        let data = try PioneerPDBWriter().write(export: export)
        let readback = try PioneerDeviceSQLReadbackInspector.inspect(data: data)
        let readbackTrack = try XCTUnwrap(readback.tables["tracks"]?.tracks.first)
        let dump = try PioneerDeviceSQLStructuralDumpBuilder.inspect(data: data)
        let decodedTrack = try XCTUnwrap(
            dump.tables.first { $0.name == "tracks" }?
                .pages
                .flatMap(\.presentRows)
                .compactMap(\.decoded)
                .first
        )

        XCTAssertEqual(readbackTrack.sampleRate, 48_000)
        XCTAssertEqual(readbackTrack.fileSize, 123_456)
        XCTAssertEqual(readbackTrack.sampleDepth, 24)
        XCTAssertEqual(readbackTrack.bitrate, 320_000)
        XCTAssertEqual(readbackTrack.tempoX100, 12_850)
        XCTAssertEqual(readbackTrack.kuvoPublic, "ON")
        XCTAssertEqual(readbackTrack.autoloadHotCues, "ON")
        XCTAssertEqual(readbackTrack.analyzeDate, "2026-06-23")
        XCTAssertEqual(decodedTrack.fields["sample_rate"], "48000")
        XCTAssertEqual(decodedTrack.fields["file_size"], "123456")
        XCTAssertEqual(decodedTrack.fields["sample_depth"], "24")
        XCTAssertEqual(decodedTrack.fields["bitrate"], "320000")
        XCTAssertEqual(decodedTrack.fields["tempo_x100"], "12850")
        XCTAssertEqual(decodedTrack.fields["bpm"], "128.50")
        XCTAssertEqual(decodedTrack.fields["kuvo_public"], "ON")
        XCTAssertEqual(decodedTrack.fields["kuvo_public_kind"], "0x07")
        XCTAssertEqual(decodedTrack.fields["kuvo_public_encoded_size"], "3")
        XCTAssertEqual(decodedTrack.fields["autoload_hot_cues"], "ON")
        XCTAssertEqual(decodedTrack.fields["autoload_hot_cues_kind"], "0x07")
        XCTAssertEqual(decodedTrack.fields["autoload_hot_cues_encoded_size"], "3")
        XCTAssertEqual(decodedTrack.fields["analyze_date"], "2026-06-23")
        XCTAssertEqual(decodedTrack.fields["analyze_date_kind"], "0x17")
        XCTAssertEqual(decodedTrack.fields["analyze_date_encoded_size"], "11")
    }

    /// Проверяет, что structural diff выводит field-level отличия track_row.
    func testStructuralDiffComparesTrackFields() throws {
        let referenceExport = try PioneerDeckExportTestSupport.makeExport()
        var generatedTracks = referenceExport.tracks
        let firstTrack = try XCTUnwrap(generatedTracks.first)
        generatedTracks[0] = PioneerDeckTrack(
            id: firstTrack.id,
            sourceTrackId: firstTrack.sourceTrackId,
            title: firstTrack.title,
            artist: firstTrack.artist,
            durationSeconds: firstTrack.durationSeconds + 1,
            sampleRate: firstTrack.sampleRate,
            fileSize: firstTrack.fileSize,
            sampleDepth: firstTrack.sampleDepth,
            bitrate: firstTrack.bitrate,
            tempoX100: firstTrack.tempoX100,
            fileName: firstTrack.fileName,
            usbRelativePath: firstTrack.usbRelativePath,
            colorId: firstTrack.colorId,
            sourceFileURL: firstTrack.sourceFileURL
        )
        let generatedExport = PioneerDeckExport(
            playlists: referenceExport.playlists,
            tracks: generatedTracks,
            colors: referenceExport.colors
        )

        let referenceDump = try PioneerDeviceSQLStructuralDumpBuilder.inspect(data: PioneerPDBWriter().write(export: referenceExport))
        let generatedDump = try PioneerDeviceSQLStructuralDumpBuilder.inspect(data: PioneerPDBWriter().write(export: generatedExport))
        let report = PioneerDeviceSQLStructuralDiff.compare(reference: referenceDump, generated: generatedDump)

        XCTAssertTrue(
            report.issues.contains {
                $0.category == "track_fixed_field"
                    && $0.path == "$.tables[tracks].presentRows[id=1].decoded.fields.duration"
                    && $0.severity == .warning
                    && $0.referenceValue == "decoded=61 raw=3d00"
                    && $0.generatedValue == "decoded=62 raw=3e00"
            }
        )
    }

    /// Проверяет, что diff показывает offset/raw bytes для fixed-field отличий track_row.
    func testStructuralDiffShowsTrackFixedFieldDiagnostics() throws {
        let export = try PioneerDeckExportTestSupport.makeExport()
        let referenceData = try PioneerPDBWriter().write(export: export)
        let referenceDump = try PioneerDeviceSQLStructuralDumpBuilder.inspect(data: referenceData)
        let rowBase = try XCTUnwrap(
            referenceDump.tables.first { $0.name == "tracks" }?
                .pages
                .flatMap(\.presentRows)
                .first { $0.decoded?.id == 1 }?
                .rowBaseFileOffset
        )

        var generatedData = referenceData
        generatedData[rowBase + 0x18] = 0x11
        generatedData[rowBase + 0x19] = 0x22

        let generatedDump = try PioneerDeviceSQLStructuralDumpBuilder.inspect(data: generatedData)
        let report = PioneerDeviceSQLStructuralDiff.compare(reference: referenceDump, generated: generatedDump)
        let issue = try XCTUnwrap(
            report.issues.first {
                $0.category == "track_fixed_field"
                    && $0.path == "$.tables[tracks].presentRows[id=1].decoded.fields.unknown_0x18"
            }
        )

        XCTAssertEqual(issue.severity, .warning)
        XCTAssertTrue(issue.message.contains("offset 0x18"))
        XCTAssertTrue(issue.message.contains("reference track_id=1 row_index=0"))
        XCTAssertEqual(issue.referenceValue, "decoded=19048 raw=684a")
        XCTAssertEqual(issue.generatedValue, "decoded=8721 raw=1122")
    }

    /// Проверяет byte-for-byte стабильность DeviceSQL export.pdb.
    func testRepeatedDeviceSQLExportPDBIsBinaryStable() throws {
        let export = try PioneerDeckExportTestSupport.makeExport()
        let writer = PioneerPDBWriter()

        XCTAssertEqual(
            try writer.write(export: export),
            try writer.write(export: export)
        )
    }

    /// Проверяет минимальный exportExt scaffold.
    func testExportExtPDBScaffoldContainsMinimalTables() throws {
        let export = try PioneerDeckExportTestSupport.makeExport()
        let data = try PioneerExportExtPDBWriter().write(export: export)
        let readback = try PioneerExportExtPDBWriter.readScaffold(from: data)

        XCTAssertEqual(readback.kind, "exportExt")
        XCTAssertEqual(Set(readback.tables.keys), ["tags", "tag_tracks", "unknown_7"])
        XCTAssertEqual(readback.tables["tags"]?.rows.count, 28)
        XCTAssertEqual(readback.tables["tag_tracks"]?.rows.count, 0)
    }
}

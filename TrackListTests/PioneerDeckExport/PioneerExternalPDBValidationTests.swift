//
//  PioneerExternalPDBValidationTests.swift
//  TrackListTests
//
//  Dev-only проверка export.pdb внешним parser'ом.
//

import Foundation
import XCTest

#if canImport(BurningTrackPioneerDeckExport)
@testable import BurningTrackPioneerDeckExport
#else
@testable import TrackList
#endif

#if os(macOS)
final class PioneerExternalPDBValidationTests: XCTestCase {
    /// Включает внешний parser только по явному запросу разработчика.
    private let runFlag = "RUN_PIONEER_EXTERNAL_PDB_VALIDATION"

    /// Проверяет generated export.pdb через rekordcrate dump-pdb, если CLI установлен локально.
    func testGeneratedExportPDBPassesRekordcrateDump() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment[runFlag] == "1" else {
            throw XCTSkip("Dev-only проверка выключена. Запуск: Scripts/PioneerDeckExport/validate_export_pdb_with_rekordcrate.sh")
        }

        let outputRoot = outputRootURL(environment: environment)
        let pdbURL = outputRoot
            .appendingPathComponent("PIONEER", isDirectory: true)
            .appendingPathComponent("rekordbox", isDirectory: true)
            .appendingPathComponent("export.pdb", isDirectory: false)
        let dumpURL = outputRoot.appendingPathComponent("rekordcrate-dump.txt", isDirectory: false)
        let reportURL = outputRoot.appendingPathComponent("rekordcrate-validation.json", isDirectory: false)

        let validationInput = try makeValidationInput(environment: environment, outputRoot: outputRoot)
        let pdbData = try PioneerPDBWriter().write(export: validationInput.export)
        let trackMappings = try generatedTrackMappings(from: pdbData, export: validationInput.export)
        let trackFileSizes = trackMappings.map(\.fileSize)
        let expectedPlaylistEntries = validationInput.export.playlists.first?.entries.map {
            RekordcratePlaylistEntry(entryIndex: $0.position, trackId: $0.trackId, playlistId: 1)
        } ?? []

        try FileManager.default.createDirectory(
            at: pdbURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try pdbData.write(to: pdbURL, options: .atomic)

        guard let rekordcrateURL = resolveRekordcrateURL(environment: environment) else {
            let installCommand = "cargo install rekordcrate"
            try writeReport(
                status: "skipped",
                parser: "rekordcrate dump-pdb",
                pdbURL: pdbURL,
                dumpURL: dumpURL,
                reportURL: reportURL,
                seenTables: [],
                orderedPlaylistTrackIds: [],
                trackFileSizes: trackFileSizes,
                manifestPath: validationInput.manifestPath,
                trackMappings: trackMappings,
                message: "rekordcrate CLI не найден. Установка: \(installCommand)"
            )
            throw XCTSkip("rekordcrate CLI не найден. Установка: \(installCommand)")
        }

        let result = try runRekordcrate(
            executableURL: rekordcrateURL,
            arguments: ["dump-pdb", pdbURL.path]
        )

        try result.stdout.write(to: dumpURL, atomically: true, encoding: .utf8)
        if !result.stderr.isEmpty {
            try result.stderr.write(
                to: outputRoot.appendingPathComponent("rekordcrate-stderr.txt", isDirectory: false),
                atomically: true,
                encoding: .utf8
            )
        }

        let seenTables = parseTables(from: result.stdout)
        let expectedPlaylistId = validationInput.export.playlists.first?.id ?? 1
        let orderedPlaylistEntries = parseOrderedPlaylistEntries(from: result.stdout, playlistId: expectedPlaylistId)
        try writeReport(
            status: result.exitCode == 0 ? "parsed" : "failed",
            parser: "rekordcrate dump-pdb",
            pdbURL: pdbURL,
            dumpURL: dumpURL,
            reportURL: reportURL,
            seenTables: seenTables.sorted(),
            orderedPlaylistTrackIds: orderedPlaylistEntries.map(\.trackId),
            trackFileSizes: trackFileSizes,
            manifestPath: validationInput.manifestPath,
            trackMappings: trackMappings,
            message: result.exitCode == 0 ? "rekordcrate завершился успешно." : result.stderr
        )

        XCTAssertEqual(result.exitCode, 0, result.stderr)
        XCTAssertTrue(seenTables.isSuperset(of: ["tracks", "colors", "playlist_tree", "playlist_entries"]))
        XCTAssertFalse(trackFileSizes.isEmpty)
        XCTAssertTrue(trackFileSizes.allSatisfy { $0 > 0 })
        XCTAssertEqual(orderedPlaylistEntries, expectedPlaylistEntries)
    }

    /// Проверяет manifest-based input без запуска внешнего rekordcrate.
    func testValidationManifestBuildsControlledTrackMapping() throws {
        let outputRoot = try PioneerDeckExportTestSupport.makeTemporaryDirectory(named: "ValidationManifest")
        let audioRoot = outputRoot.appendingPathComponent("audio", isDirectory: true)
        try FileManager.default.createDirectory(at: audioRoot, withIntermediateDirectories: true)

        let firstURL = audioRoot.appendingPathComponent("first.flac", isDirectory: false)
        let secondURL = audioRoot.appendingPathComponent("second.flac", isDirectory: false)
        try Data(repeating: 1, count: 11).write(to: firstURL)
        try Data(repeating: 2, count: 22).write(to: secondURL)

        let manifestURL = outputRoot.appendingPathComponent("manifest.json", isDirectory: false)
        let manifest = """
        {
          "playlistName": "Manifest Playlist",
          "tracks": [
            {
              "trackId": 7,
              "sourceFilePath": "\(firstURL.path)",
              "title": "First Manifest",
              "artist": "Artist A",
              "album": "Album A",
              "fileName": "first.flac",
              "durationSeconds": 101,
              "sampleRate": 44100,
              "sampleDepth": 16,
              "bitrate": 900,
              "tempoX100": 12345,
              "analyzeDate": "2026-06-23"
            },
            {
              "trackId": 3,
              "sourceFilePath": "\(secondURL.path)",
              "title": "Second Manifest",
              "artist": "Artist B",
              "fileName": "second.flac",
              "durationSeconds": 202
            }
          ]
        }
        """
        try manifest.write(to: manifestURL, atomically: true, encoding: .utf8)

        let input = try makeValidationInput(
            environment: ["PIONEER_VALIDATION_MANIFEST": manifestURL.path],
            outputRoot: outputRoot
        )

        XCTAssertEqual(input.manifestPath, manifestURL.path)
        XCTAssertEqual(input.export.playlists.first?.name, "Manifest Playlist")
        XCTAssertEqual(input.export.playlists.first?.entries.map(\.trackId), [7, 3])
        XCTAssertEqual(input.export.tracks.map(\.id), [7, 3])
        XCTAssertEqual(input.export.tracks.map(\.fileSize), [11, 22])
        XCTAssertEqual(input.export.tracks[0].sampleRate, 44_100)
        XCTAssertEqual(input.export.tracks[0].sampleDepth, 16)
        XCTAssertEqual(input.export.tracks[0].bitrate, 900)
        XCTAssertEqual(input.export.tracks[0].tempoX100, 12_345)
        XCTAssertEqual(input.export.tracks[0].analyzeDate, "2026-06-23")

        let data = try PioneerPDBWriter().write(export: input.export)
        let mappings = try generatedTrackMappings(from: data, export: input.export)
        XCTAssertEqual(mappings.map(\.trackId), [7, 3])
        XCTAssertEqual(mappings.map(\.analyzePath), [
            "/PIONEER/USBANLZ/P001/00000007/ANLZ0000.DAT",
            "/PIONEER/USBANLZ/P001/00000003/ANLZ0000.DAT"
        ])
    }

    /// Собирает входные данные validation из manifest или fallback-fixture.
    private func makeValidationInput(environment: [String: String], outputRoot: URL) throws -> ValidationInput {
        if let manifestPath = environment["PIONEER_VALIDATION_MANIFEST"], !manifestPath.isEmpty {
            let manifestURL = URL(fileURLWithPath: manifestPath, isDirectory: false)
            let export = try makeManifestExport(manifestURL: manifestURL)
            return ValidationInput(export: export, manifestPath: manifestURL.path)
        }

        let sourceURLs = try validationSourceURLs(environment: environment, outputRoot: outputRoot)
        return ValidationInput(
            export: try PioneerDeckExportTestSupport.makeReorderedExport(sourceURLs: sourceURLs),
            manifestPath: nil
        )
    }

    /// Строит validation export напрямую по manifest, без сортировки файлов в папке.
    private func makeManifestExport(manifestURL: URL) throws -> PioneerDeckExport {
        let data = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(ValidationManifest.self, from: data)
        guard !manifest.tracks.isEmpty else {
            throw PioneerDeckExportError.invalidBinaryLayout("PIONEER_VALIDATION_MANIFEST не содержит tracks.")
        }

        let trackIds = manifest.tracks.map(\.trackId)
        guard Set(trackIds).count == trackIds.count else {
            throw PioneerDeckExportError.duplicateTrackId
        }

        let tracks = try manifest.tracks.map { manifestTrack in
            let sourceURL = URL(fileURLWithPath: manifestTrack.sourceFilePath, isDirectory: false)
            guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                throw PioneerDeckExportError.invalidBinaryLayout("Файл из PIONEER_VALIDATION_MANIFEST не найден: \(sourceURL.path)")
            }

            let artist = manifestTrack.artist ?? ""
            let fileName = manifestTrack.fileName.nilIfBlank ?? sourceURL.lastPathComponent
            let title = manifestTrack.title.nilIfBlank ?? URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
            return PioneerDeckTrack(
                id: manifestTrack.trackId,
                sourceTrackId: sourceUUID(trackId: manifestTrack.trackId),
                title: title,
                artist: artist,
                durationSeconds: manifestTrack.durationSeconds ?? 0,
                sampleRate: manifestTrack.sampleRate,
                fileSize: fileSizeFromSourceURL(sourceURL),
                sampleDepth: manifestTrack.sampleDepth,
                bitrate: manifestTrack.bitrate,
                tempoX100: manifestTrack.tempoX100,
                analyzeDate: manifestTrack.analyzeDate.nilIfBlank,
                fileName: fileName,
                usbRelativePath: PlaceholderAudioLayoutStrategy().audioUSBPath(
                    artist: artist,
                    album: manifestTrack.album.nilIfBlank ?? manifest.playlistName.nilIfBlank,
                    fileName: fileName
                ),
                colorId: manifestTrack.colorId ?? 0,
                sourceFileURL: sourceURL
            )
        }

        let playlist = PioneerDeckPlaylist(
            id: manifest.playlistId ?? 1,
            sourcePlaylistId: sourceUUID(trackId: 1_000_000),
            name: manifest.playlistName.nilIfBlank ?? "Validation Manifest",
            entries: manifest.tracks.enumerated().map { index, track in
                PioneerDeckPlaylistEntry(trackId: track.trackId, position: UInt32(index + 1))
            }
        )

        let export = PioneerDeckExport(playlists: [playlist], tracks: tracks)
        try export.validate()
        return export
    }

    /// Возвращает sourceFileURL для validation export: env fixture или стабильные dummy-файлы.
    private func validationSourceURLs(environment: [String: String], outputRoot: URL) throws -> [UUID: URL] {
        let sourceTrackIds = PioneerDeckExportTestSupport.sourceTrackIds
        if let rawAudioDirectory = environment["PIONEER_VALIDATION_AUDIO_DIR"], !rawAudioDirectory.isEmpty {
            let urls = try audioFiles(in: URL(fileURLWithPath: rawAudioDirectory, isDirectory: true))
            guard !urls.isEmpty else {
                throw PioneerDeckExportError.invalidBinaryLayout("PIONEER_VALIDATION_AUDIO_DIR не содержит поддерживаемых аудиофайлов.")
            }

            var sourceURLs = Dictionary(uniqueKeysWithValues: zip(sourceTrackIds, urls.prefix(sourceTrackIds.count)))
            if sourceURLs.count < sourceTrackIds.count {
                let dummyURLs = try makeDummyAudioSources(outputRoot: outputRoot)
                for id in sourceTrackIds where sourceURLs[id] == nil {
                    sourceURLs[id] = dummyURLs[id]
                }
            }
            return sourceURLs
        }

        return try makeDummyAudioSources(outputRoot: outputRoot)
    }

    /// Создаёт стабильные dummy-файлы для validation, когда реальная audio fixture не задана.
    private func makeDummyAudioSources(outputRoot: URL) throws -> [UUID: URL] {
        let sourceAudioRoot = outputRoot.appendingPathComponent("source-audio", isDirectory: true)
        if FileManager.default.fileExists(atPath: sourceAudioRoot.path) {
            try FileManager.default.removeItem(at: sourceAudioRoot)
        }
        try FileManager.default.createDirectory(at: sourceAudioRoot, withIntermediateDirectories: true)
        return try PioneerDeckExportTestSupport.makeAudioSources(in: sourceAudioRoot)
    }

    /// Возвращает первые audio-файлы из dev-only fixture directory.
    private func audioFiles(in directory: URL) throws -> [URL] {
        let supportedExtensions: Set<String> = ["aac", "aif", "aiff", "alac", "flac", "m4a", "mp3", "mp4", "wav"]
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw PioneerDeckExportError.invalidBinaryLayout("Не удалось открыть PIONEER_VALIDATION_AUDIO_DIR: \(directory.path)")
        }

        var urls: [URL] = []
        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey])
            guard values.isRegularFile == true else { continue }
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            urls.append(url)
        }
        return urls.sorted { $0.path < $1.path }
    }

    /// Читает file_size из только что сгенерированного export.pdb и связывает его с source file.
    private func generatedTrackMappings(from data: Data, export: PioneerDeckExport) throws -> [ValidationTrackMapping] {
        let dump = try PioneerDeviceSQLReadbackInspector.inspect(data: data)
        let readbackById = Dictionary(uniqueKeysWithValues: (dump.tables["tracks"]?.tracks ?? []).map { ($0.id, $0) })
        return export.tracks.map { track in
            ValidationTrackMapping(
                trackId: track.id,
                sourceFilePath: track.sourceFileURL?.path ?? "",
                fileName: track.fileName,
                title: track.title,
                fileSize: readbackById[track.id]?.fileSize ?? 0,
                analyzePath: readbackById[track.id]?.analyzePath ?? ""
            )
        }
    }

    /// Читает размер исходного файла для manifest track_row.
    private func fileSizeFromSourceURL(_ url: URL) -> UInt32? {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
            let size = attributes[.size] as? NSNumber
        else {
            return nil
        }
        return UInt32(exactly: size.uint64Value)
    }

    /// Создаёт стабильный UUID для manifest-строк, не влияющий на track_id.
    private func sourceUUID(trackId: UInt32) -> UUID {
        let suffix = String(format: "%012u", trackId)
        return UUID(uuidString: "90000000-0000-0000-0000-\(suffix)")!
    }

    /// Возвращает корневую директорию для dev-only артефактов.
    private func outputRootURL(environment: [String: String]) -> URL {
        if let rawPath = environment["PIONEER_EXTERNAL_PDB_OUTPUT_DIR"], !rawPath.isEmpty {
            return URL(fileURLWithPath: rawPath, isDirectory: true)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("pioneer-external-pdb-validation", isDirectory: true)
    }

    /// Ищет rekordcrate по REKORDCRATE_BIN или PATH.
    private func resolveRekordcrateURL(environment: [String: String]) -> URL? {
        if let rawPath = environment["REKORDCRATE_BIN"], !rawPath.isEmpty {
            let url = URL(fileURLWithPath: rawPath, isDirectory: false)
            return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
        }

        return findExecutable(named: "rekordcrate", path: environment["PATH"] ?? "")
    }

    /// Ищет executable в PATH.
    private func findExecutable(named name: String, path: String) -> URL? {
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory), isDirectory: true)
                .appendingPathComponent(name, isDirectory: false)
            if FileManager.default.isExecutableFile(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// Запускает rekordcrate и возвращает stdout/stderr.
    private func runRekordcrate(executableURL: URL, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        return ProcessResult(
            exitCode: process.terminationStatus,
            stdout: String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
            stderr: String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        )
    }

    /// Извлекает имена таблиц из debug-dump формата rekordcrate.
    private func parseTables(from dump: String) -> Set<String> {
        var tables = Set<String>()
        for line in dump.components(separatedBy: .newlines) where line.hasPrefix("Table ") {
            if line.contains("Tracks") {
                tables.insert("tracks")
            }
            if line.contains("Colors") {
                tables.insert("colors")
            }
            if line.contains("PlaylistTree") {
                tables.insert("playlist_tree")
            }
            if line.contains("PlaylistEntries") {
                tables.insert("playlist_entries")
            }
        }
        return tables
    }

    /// Извлекает playlist_entries из ordered-строк rekordcrate dump-pdb.
    private func parseOrderedPlaylistEntries(from dump: String, playlistId: UInt32) -> [RekordcratePlaylistEntry] {
        let pattern = #"entry_index: ([0-9]+), track_id: TrackId\(([0-9]+)\), playlist_id: PlaylistTreeNodeId\(([0-9]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        return dump.components(separatedBy: .newlines).compactMap { line in
            guard line.hasPrefix("      PlaylistEntry(") else { return nil }
            let range = NSRange(line.startIndex..<line.endIndex, in: line)
            guard let match = regex.firstMatch(in: line, range: range), match.numberOfRanges == 4 else {
                return nil
            }
            guard
                let entryIndex = UInt32(stringAtRange(1, in: line, match: match)),
                let trackId = UInt32(stringAtRange(2, in: line, match: match)),
                let parsedPlaylistId = UInt32(stringAtRange(3, in: line, match: match)),
                parsedPlaylistId == playlistId
            else {
                return nil
            }
            return RekordcratePlaylistEntry(
                entryIndex: entryIndex,
                trackId: trackId,
                playlistId: parsedPlaylistId
            )
        }
    }

    /// Возвращает строку из capture-группы regex.
    private func stringAtRange(_ index: Int, in line: String, match: NSTextCheckingResult) -> String {
        let range = match.range(at: index)
        guard let swiftRange = Range(range, in: line) else { return "" }
        return String(line[swiftRange])
    }

    /// Сохраняет JSON-отчёт dev-only проверки.
    private func writeReport(
        status: String,
        parser: String,
        pdbURL: URL,
        dumpURL: URL,
        reportURL: URL,
        seenTables: [String],
        orderedPlaylistTrackIds: [UInt32],
        trackFileSizes: [UInt32],
        manifestPath: String?,
        trackMappings: [ValidationTrackMapping],
        message: String
    ) throws {
        let payload: [String: Any] = [
            "status": status,
            "parser": parser,
            "pdbPath": pdbURL.path,
            "dumpPath": dumpURL.path,
            "seenTables": seenTables,
            "requiredTables": ["tracks", "colors", "playlist_tree", "playlist_entries"],
            "orderedPlaylistTrackIds": orderedPlaylistTrackIds,
            "manifestPath": manifestPath ?? "",
            "trackMappings": trackMappings.map(\.jsonObject),
            "trackFileSizes": trackFileSizes,
            "message": message
        ]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: reportURL, options: .atomic)
    }
}

/// Результат запуска внешнего процесса.
private struct ValidationInput {
    /// Сформированная export-модель.
    let export: PioneerDeckExport

    /// Путь manifest, если validation использует manifest-based fixture.
    let manifestPath: String?
}

/// Manifest-based описание validation fixture.
private struct ValidationManifest: Decodable {
    /// Id validation playlist.
    let playlistId: UInt32?

    /// Имя validation playlist.
    let playlistName: String?

    /// Треки в точном порядке manifest.
    let tracks: [ValidationManifestTrack]
}

/// Один трек manifest-based validation fixture.
private struct ValidationManifestTrack: Decodable {
    /// Track id, который будет записан в export.pdb.
    let trackId: UInt32

    /// Абсолютный путь к исходному аудиофайлу.
    let sourceFilePath: String

    /// Название трека.
    let title: String?

    /// Исполнитель.
    let artist: String?

    /// Альбом для placeholder audio layout validation.
    let album: String?

    /// Имя файла для track_row.
    let fileName: String?

    /// Длительность в секундах.
    let durationSeconds: UInt32?

    /// Sample rate, если известен.
    let sampleRate: UInt32?

    /// Bit depth, если известен.
    let sampleDepth: UInt16?

    /// Bitrate, если известен.
    let bitrate: UInt32?

    /// BPM * 100, если известен.
    let tempoX100: UInt32?

    /// Дата анализа в формате YYYY-MM-DD, если известна.
    let analyzeDate: String?

    /// Color id, если нужен для validation.
    let colorId: UInt32?
}

/// Mapping, который попадает в validation JSON report.
private struct ValidationTrackMapping {
    /// Track id из export.pdb.
    let trackId: UInt32

    /// Source file path, использованный для file_size.
    let sourceFilePath: String

    /// Имя файла из export-модели.
    let fileName: String

    /// Название из export-модели.
    let title: String

    /// file_size, прочитанный из generated export.pdb.
    let fileSize: UInt32

    /// analyze_path, прочитанный из generated export.pdb.
    let analyzePath: String

    /// JSON-compatible представление.
    var jsonObject: [String: Any] {
        [
            "trackId": trackId,
            "sourceFilePath": sourceFilePath,
            "fileName": fileName,
            "title": title,
            "fileSize": fileSize,
            "analyzePath": analyzePath
        ]
    }
}

/// Результат запуска внешнего процесса.
private struct ProcessResult {
    /// Код завершения.
    let exitCode: Int32

    /// Стандартный вывод.
    let stdout: String

    /// Стандартная ошибка.
    let stderr: String
}

/// Строка playlist_entries, прочитанная внешним rekordcrate.
private struct RekordcratePlaylistEntry: Equatable {
    /// Позиция трека внутри плейлиста.
    let entryIndex: UInt32

    /// Id трека.
    let trackId: UInt32

    /// Id плейлиста.
    let playlistId: UInt32
}

private extension Optional where Wrapped == String {
    /// Возвращает nil для пустых и пробельных строк.
    var nilIfBlank: String? {
        guard let value = self else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
#endif

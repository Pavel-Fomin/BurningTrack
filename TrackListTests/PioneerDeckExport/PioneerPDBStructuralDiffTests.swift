//
//  PioneerPDBStructuralDiffTests.swift
//  TrackListTests
//
//  Dev-only structural diff настоящего rekordbox export.pdb и generated export.pdb.
//

import Foundation
import XCTest

#if canImport(BurningTrackPioneerDeckExport)
@testable import BurningTrackPioneerDeckExport
#else
@testable import TrackList
#endif

#if os(macOS)
final class PioneerPDBStructuralDiffTests: XCTestCase {
    /// Env var с путём к reference export.pdb, созданному rekordbox.
    private let referencePathKey = "PIONEER_REFERENCE_PDB"

    /// Env var с путём к generated export.pdb, созданному BurningTrack.
    private let generatedPathKey = "PIONEER_GENERATED_PDB"

    /// Dev-only test entry point для structural diff.
    func testReferenceAndGeneratedExportPDBStructuralDiff() throws {
        let environment = ProcessInfo.processInfo.environment
        guard
            let referencePath = environment[referencePathKey],
            !referencePath.isEmpty,
            let generatedPath = environment[generatedPathKey],
            !generatedPath.isEmpty
        else {
            throw XCTSkip("Dev-only diff выключен. Передайте PIONEER_REFERENCE_PDB и PIONEER_GENERATED_PDB.")
        }

        let outputRoot = outputRootURL(environment: environment)
        try FileManager.default.createDirectory(at: outputRoot, withIntermediateDirectories: true)

        do {
            let referenceDump = try makeDump(path: referencePath)
            let generatedDump = try makeDump(path: generatedPath)
            let report = PioneerDeviceSQLStructuralDiff.compare(
                reference: referenceDump,
                generated: generatedDump
            )

            try writeJSON(
                referenceDump,
                to: outputRoot.appendingPathComponent("reference-dump.json", isDirectory: false)
            )
            try writeJSON(
                generatedDump,
                to: outputRoot.appendingPathComponent("generated-dump.json", isDirectory: false)
            )
            try writeJSON(
                report,
                to: outputRoot.appendingPathComponent("diff-report.json", isDirectory: false)
            )
            try report.textReport().write(
                to: outputRoot.appendingPathComponent("diff-report.txt", isDirectory: false),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            let message = "Pioneer DeviceSQL structural diff failed: \(error)"
            try message.write(
                to: outputRoot.appendingPathComponent("diff-report.txt", isDirectory: false),
                atomically: true,
                encoding: .utf8
            )
            XCTFail(message)
        }
    }

    /// Строит tolerant structural dump файла.
    private func makeDump(path: String) throws -> PioneerDeviceSQLStructuralDump {
        let url = URL(fileURLWithPath: path, isDirectory: false)
        let data = try Data(contentsOf: url)
        return try PioneerDeviceSQLStructuralDumpBuilder.inspect(data: data)
    }

    /// Возвращает директорию dev-only артефактов.
    private func outputRootURL(environment: [String: String]) -> URL {
        if let rawPath = environment["PIONEER_PDB_DIFF_OUTPUT_DIR"], !rawPath.isEmpty {
            return URL(fileURLWithPath: rawPath, isDirectory: true)
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
            .appendingPathComponent(".build", isDirectory: true)
            .appendingPathComponent("pioneer-pdb-diff", isDirectory: true)
    }

    /// Сохраняет Codable payload как стабильный JSON.
    private func writeJSON<T: Encodable>(_ payload: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(payload).write(to: url, options: .atomic)
    }
}
#endif

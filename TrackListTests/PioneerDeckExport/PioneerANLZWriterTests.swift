//
//  PioneerANLZWriterTests.swift
//  TrackListTests
//
//  Readback-тесты минимальных ANLZ-контейнеров.
//

import XCTest

#if canImport(BurningTrackPioneerDeckExport)
@testable import BurningTrackPioneerDeckExport
#else
@testable import TrackList
#endif

final class PioneerANLZWriterTests: XCTestCase {
    /// Проверяет PPTH и пустые cue-блоки в DAT.
    func testDATContainsPPTHAndEmptyCueBlocks() throws {
        let audioPath = "/Contents/Artist/UnknownAlbum/track.m4a"
        let files = PioneerANLZWriter().makeFiles(audioPath: audioPath)
        let readback = try PioneerANLZWriter.readSections(from: files.dat)

        XCTAssertEqual(readback.headerLength, 28)
        XCTAssertEqual(Int(readback.fileLength), files.dat.count)
        XCTAssertEqual(readback.ppThPath, audioPath)
        XCTAssertEqual(readback.sections.map(\.fourCC), ["PPTH", "PCOB", "PCOB"])
        XCTAssertEqual(readback.sections.filter { $0.fourCC == "PCOB" }.count, 2)
    }

    /// Проверяет PPTH и extended cue-блоки в EXT.
    func testEXTContainsPPTHAndExtendedCueBlocks() throws {
        let audioPath = "/Contents/Artist/UnknownAlbum/track.m4a"
        let files = PioneerANLZWriter().makeFiles(audioPath: audioPath)
        let readback = try PioneerANLZWriter.readSections(from: files.ext)

        XCTAssertEqual(readback.ppThPath, audioPath)
        XCTAssertEqual(readback.sections.map(\.fourCC), ["PPTH", "PCOB", "PCOB", "PCO2", "PCO2"])
    }

    /// Проверяет минимальный 2EX-контейнер.
    func test2EXContainsOnlyPPTHForFirstImplementation() throws {
        let audioPath = "/Contents/Artist/UnknownAlbum/track.m4a"
        let files = PioneerANLZWriter().makeFiles(audioPath: audioPath)
        let readback = try PioneerANLZWriter.readSections(from: files.twoEX)

        XCTAssertEqual(readback.ppThPath, audioPath)
        XCTAssertEqual(readback.sections.map(\.fourCC), ["PPTH"])
    }
}

//
//  PioneerDeckUSBExportGoldenTests.swift
//  TrackListTests
//
//  Golden-тест детерминированной генерации PIONEER-структуры.
//

import XCTest

#if canImport(BurningTrackPioneerDeckExport)
@testable import BurningTrackPioneerDeckExport
#else
@testable import TrackList
#endif

final class PioneerDeckUSBExportGoldenTests: XCTestCase {
    /// Проверяет, что одинаковая модель дважды даёт одинаковые байты и одинаковые пути.
    func testRepeatedUSBExportIsBinaryStable() throws {
        let fixtureRoot = try PioneerDeckExportTestSupport.makeTemporaryDirectory(named: "GoldenFixture")
        let sourceURLs = try PioneerDeckExportTestSupport.makeAudioSources(in: fixtureRoot)
        let export = try PioneerDeckExportTestSupport.makeExport(sourceURLs: sourceURLs)
        let firstRoot = try PioneerDeckExportTestSupport.makeTemporaryDirectory(named: "GoldenFirst")
        let secondRoot = try PioneerDeckExportTestSupport.makeTemporaryDirectory(named: "GoldenSecond")

        let writer = PioneerDeckUSBExportWriter()
        try writer.write(export: export, to: firstRoot)
        try writer.write(export: export, to: secondRoot)

        let firstFiles = try PioneerDeckExportTestSupport.collectFiles(root: firstRoot.appendingPathComponent("PIONEER"))
        let secondFiles = try PioneerDeckExportTestSupport.collectFiles(root: secondRoot.appendingPathComponent("PIONEER"))

        XCTAssertEqual(Set(firstFiles.keys), Set(secondFiles.keys))
        XCTAssertEqual(firstFiles, secondFiles)
        XCTAssertTrue(firstFiles.keys.contains("rekordbox/export.pdb"))
        XCTAssertTrue(firstFiles.keys.contains("rekordbox/exportExt.pdb"))
        XCTAssertTrue(firstFiles.keys.contains("USBANLZ/P001/00000001/ANLZ0000.DAT"))
        XCTAssertTrue(firstFiles.keys.contains("USBANLZ/P001/00000001/ANLZ0000.EXT"))
        XCTAssertTrue(firstFiles.keys.contains("USBANLZ/P001/00000001/ANLZ0000.2EX"))
        XCTAssertTrue(firstFiles.keys.contains("MYSETTING.DAT"))
        XCTAssertTrue(firstFiles.keys.contains("MYSETTING2.DAT"))
        XCTAssertTrue(firstFiles.keys.contains("DJMMYSETTING.DAT"))
        XCTAssertTrue(firstFiles.keys.contains("djprofile.nxs"))
    }
}

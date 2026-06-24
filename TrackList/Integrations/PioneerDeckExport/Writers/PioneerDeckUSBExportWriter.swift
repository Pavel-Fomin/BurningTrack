//
//  PioneerDeckUSBExportWriter.swift
//  TrackList
//
//  Фасад записи структуры PIONEER на выбранный USB root.
//

import Foundation

/// Записывает первую изолированную структуру PIONEER без подключения к UI.
public final class PioneerDeckUSBExportWriter {
    /// Файловая система, внедряемая для тестируемости.
    private let fileManager: FileManager

    /// Writer legacy DeviceSQL export.pdb.
    private let pdbWriter: PioneerPDBWriter

    /// Writer exportExt.pdb scaffold.
    private let extPDBWriter: PioneerExportExtPDBWriter

    /// Writer минимальных ANLZ-файлов.
    private let anlzWriter: PioneerANLZWriter

    /// Временная стратегия построения путей USBANLZ, внедрённая через DI.
    private let usbANLZPathStrategy: any PioneerUSBANLZPathStrategy

    /// Управляет заменой существующей папки PIONEER.
    private let replaceExistingPioneerDirectory: Bool

    /// Создаёт фасад USB writer-слоя.
    public init(
        fileManager: FileManager = .default,
        pdbWriter: PioneerPDBWriter = PioneerPDBWriter(),
        extPDBWriter: PioneerExportExtPDBWriter = PioneerExportExtPDBWriter(),
        anlzWriter: PioneerANLZWriter = PioneerANLZWriter(),
        usbANLZPathStrategy: any PioneerUSBANLZPathStrategy = PlaceholderUSBANLZPathStrategy(),
        replaceExistingPioneerDirectory: Bool = true
    ) {
        self.fileManager = fileManager
        self.pdbWriter = pdbWriter
        self.extPDBWriter = extPDBWriter
        self.anlzWriter = anlzWriter
        self.usbANLZPathStrategy = usbANLZPathStrategy
        self.replaceExistingPioneerDirectory = replaceExistingPioneerDirectory
    }

    /// Создаёт PIONEER-структуру в переданном корне USB-носителя.
    public func write(export: PioneerDeckExport, to usbRootURL: URL) throws {
        try export.validate()

        let pioneerRoot = usbRootURL.appendingPathComponent("PIONEER", isDirectory: true)
        if replaceExistingPioneerDirectory, fileManager.fileExists(atPath: pioneerRoot.path) {
            try fileManager.removeItem(at: pioneerRoot)
        }

        try fileManager.createDirectory(at: pioneerRoot, withIntermediateDirectories: true)
        try writeAudioFiles(export.tracks, pioneerRoot: pioneerRoot)
        try writeDatabases(export, pioneerRoot: pioneerRoot)
        try writeANLZFiles(export.tracks, pioneerRoot: pioneerRoot)
        try PioneerDeviceSettingsWriter(fileManager: fileManager).writeSettings(to: pioneerRoot)
    }

    /// Копирует аудиофайлы в путь, заданный текущей audio layout strategy.
    private func writeAudioFiles(_ tracks: [PioneerDeckTrack], pioneerRoot: URL) throws {
        for track in tracks {
            guard let sourceURL = track.sourceFileURL else {
                throw PioneerDeckExportError.missingSourceFile(trackId: track.id, fileName: track.fileName)
            }
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                throw PioneerDeckExportError.sourceFileNotFound(sourceURL.path)
            }

            let relativePath = try PioneerExportPathSanitizer.relativeFilePathInsidePioneer(track.usbRelativePath)
            let destinationURL = pioneerRoot.appendingPathComponent(relativePath, isDirectory: false)
            try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
    }

    /// Пишет export.pdb и exportExt.pdb в PIONEER/rekordbox.
    private func writeDatabases(_ export: PioneerDeckExport, pioneerRoot: URL) throws {
        let rekordboxURL = pioneerRoot.appendingPathComponent("rekordbox", isDirectory: true)
        try fileManager.createDirectory(at: rekordboxURL, withIntermediateDirectories: true)

        try pdbWriter
            .write(export: export)
            .write(to: rekordboxURL.appendingPathComponent("export.pdb"), options: .atomic)

        try extPDBWriter
            .write(export: export)
            .write(to: rekordboxURL.appendingPathComponent("exportExt.pdb"), options: .atomic)
    }

    /// Пишет ANLZ0000.DAT, ANLZ0000.EXT и ANLZ0000.2EX для каждого трека.
    private func writeANLZFiles(_ tracks: [PioneerDeckTrack], pioneerRoot: URL) throws {
        for track in tracks {
            let directory = pioneerRoot.appendingPathComponent(usbANLZPathStrategy.anlzDirectoryRelativePath(for: track.id), isDirectory: true)
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

            let files = anlzWriter.makeFiles(audioPath: track.usbRelativePath)
            try files.dat.write(to: directory.appendingPathComponent("ANLZ0000.DAT"), options: .atomic)
            try files.ext.write(to: directory.appendingPathComponent("ANLZ0000.EXT"), options: .atomic)
            try files.twoEX.write(to: directory.appendingPathComponent("ANLZ0000.2EX"), options: .atomic)
        }
    }
}

/// Пишет минимальные settings/profile файлы, описанные каноничным документом.
private struct PioneerDeviceSettingsWriter {
    /// Файловая система для тестируемости.
    let fileManager: FileManager

    /// Пишет стабильные placeholder-настройки без пользовательских параметров.
    func writeSettings(to pioneerRoot: URL) throws {
        try makeSettingsFile(brand: "PIONEER", version: "0.001", bodyLength: 40)
            .write(to: pioneerRoot.appendingPathComponent("MYSETTING.DAT"), options: .atomic)

        try makeSettingsFile(brand: "PIONEER", version: "0.001", bodyLength: 40)
            .write(to: pioneerRoot.appendingPathComponent("MYSETTING2.DAT"), options: .atomic)

        try makeSettingsFile(brand: "PioneerDJ", version: "1.000", bodyLength: 52)
            .write(to: pioneerRoot.appendingPathComponent("DJMMYSETTING.DAT"), options: .atomic)

        try makeProfileFile(profileName: "BurningTrack")
            .write(to: pioneerRoot.appendingPathComponent("djprofile.nxs"), options: .atomic)
    }

    /// Создаёт общий MYSETTING/DJMMYSETTING header с нулевым body и footer.
    private func makeSettingsFile(brand: String, version: String, bodyLength: Int) -> Data {
        var writer = BinaryDataWriter()
        writer.appendUInt32LE(96)
        writer.appendFixedASCII(brand, length: 32)
        writer.appendFixedASCII("rekordbox", length: 32)
        writer.appendFixedASCII(version, length: 32)
        writer.appendUInt32LE(UInt32(bodyLength))
        writer.appendZeroes(bodyLength)
        writer.appendUInt32LE(0)
        return writer.data
    }

    /// Создаёт 160-байтный djprofile.nxs с именем профиля по offset 0x20.
    private func makeProfileFile(profileName: String) -> Data {
        var writer = BinaryDataWriter()
        writer.appendZeroes(0x20)
        writer.appendFixedASCII(profileName, length: 32)
        writer.pad(toLength: 160)
        return writer.data
    }
}

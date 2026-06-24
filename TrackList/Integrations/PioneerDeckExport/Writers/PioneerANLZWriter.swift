//
//  PioneerANLZWriter.swift
//  TrackList
//
//  Минимальные ANLZ-контейнеры с PPTH и пустыми cue-блоками.
//

import Foundation

/// Пишет ANLZ0000.DAT, ANLZ0000.EXT и ANLZ0000.2EX без waveform/beat grid анализа.
public struct PioneerANLZWriter {
    /// Заголовок PMAI из каноничного документа имеет длину 28 байт.
    private static let headerLength: UInt32 = 28

    /// Создаёт writer.
    public init() {}

    /// Формирует три ANLZ-файла для одного трека.
    public func makeFiles(audioPath: String) -> PioneerANLZFileSet {
        PioneerANLZFileSet(
            dat: makeDAT(audioPath: audioPath),
            ext: makeEXT(audioPath: audioPath),
            twoEX: make2EX(audioPath: audioPath)
        )
    }

    /// Читает секции ANLZ для readback-тестов.
    public static func readSections(from data: Data) throws -> PioneerANLZReadback {
        var reader = BinaryDataReader(data: data)
        let magic = try String(data: reader.readData(count: 4), encoding: .ascii) ?? ""
        guard magic == "PMAI" else {
            throw PioneerDeckExportError.invalidBinaryLayout("ANLZ не начинается с PMAI.")
        }

        let headerLength = try reader.readUInt32BE()
        let fileLength = try reader.readUInt32BE()
        guard Int(fileLength) <= data.count else {
            throw PioneerDeckExportError.invalidBinaryLayout("ANLZ len_file больше фактического файла.")
        }

        try reader.seek(to: Int(headerLength))
        var sections: [PioneerANLZSection] = []
        while !reader.isAtEnd {
            let fourCCData = try reader.readData(count: 4)
            guard let fourCC = String(data: fourCCData, encoding: .ascii), !fourCC.trimmingCharacters(in: .controlCharacters).isEmpty else {
                throw PioneerDeckExportError.invalidBinaryLayout("ANLZ section fourcc не декодируется.")
            }

            let sectionHeaderLength = try reader.readUInt32BE()
            let sectionLength = try reader.readUInt32BE()
            guard sectionHeaderLength == 12, sectionLength >= sectionHeaderLength else {
                throw PioneerDeckExportError.invalidBinaryLayout("Некорректная длина ANLZ section \(fourCC).")
            }

            let bodyLength = Int(sectionLength - sectionHeaderLength)
            let body = try reader.readData(count: bodyLength)
            sections.append(PioneerANLZSection(fourCC: fourCC, headerLength: sectionHeaderLength, length: sectionLength, body: body))
        }

        return PioneerANLZReadback(headerLength: headerLength, fileLength: fileLength, sections: sections)
    }

    /// DAT содержит путь и два legacy cue-list блока: hot cues и memory cues.
    private func makeDAT(audioPath: String) -> Data {
        makeANLZ(sections: [
            makePPTH(audioPath),
            makePCOB(type: 1),
            makePCOB(type: 0)
        ])
    }

    /// EXT содержит путь, legacy cue-list и extended cue-list блоки.
    private func makeEXT(audioPath: String) -> Data {
        makeANLZ(sections: [
            makePPTH(audioPath),
            makePCOB(type: 1),
            makePCOB(type: 0),
            makePCO2(type: 1),
            makePCO2(type: 0)
        ])
    }

    /// 2EX на первом этапе содержит только путь к аудиофайлу.
    private func make2EX(audioPath: String) -> Data {
        makeANLZ(sections: [
            makePPTH(audioPath)
        ])
    }

    /// Собирает общий PMAI-контейнер.
    private func makeANLZ(sections: [Data]) -> Data {
        var writer = BinaryDataWriter()
        writer.appendASCII("PMAI")
        writer.appendUInt32BE(Self.headerLength)
        writer.appendUInt32BE(0)
        writer.appendZeroes(Int(Self.headerLength) - writer.count)

        sections.forEach { writer.appendData($0) }
        writer.patchUInt32BE(UInt32(writer.count), at: 8)
        return writer.data
    }

    /// PPTH хранит путь к аудиофайлу в UTF-16BE.
    private func makePPTH(_ audioPath: String) -> Data {
        var body = BinaryDataWriter()
        body.appendUTF16BE(audioPath, terminated: true)
        return makeSection(fourCC: "PPTH", body: body.data)
    }

    /// PCOB scaffold хранит тип списка и нулевой count, точная body-схема требует golden-образца.
    private func makePCOB(type: UInt32) -> Data {
        var body = BinaryDataWriter()
        body.appendUInt32BE(type)
        body.appendUInt32BE(0)
        return makeSection(fourCC: "PCOB", body: body.data)
    }

    /// PCO2 scaffold хранит тип списка и нулевой count для EXT.
    private func makePCO2(type: UInt32) -> Data {
        var body = BinaryDataWriter()
        body.appendUInt32BE(type)
        body.appendUInt32BE(0)
        return makeSection(fourCC: "PCO2", body: body.data)
    }

    /// Собирает section с 12-байтным header: fourcc, len_header, len_tag.
    private func makeSection(fourCC: String, body: Data) -> Data {
        var writer = BinaryDataWriter()
        writer.appendFixedASCII(fourCC, length: 4)
        writer.appendUInt32BE(12)
        writer.appendUInt32BE(UInt32(body.count + 12))
        writer.appendData(body)
        return writer.data
    }
}

/// Набор трёх ANLZ-файлов для одного трека.
public struct PioneerANLZFileSet: Equatable {
    /// Legacy DAT-файл.
    public let dat: Data

    /// Расширенный EXT-файл.
    public let ext: Data

    /// Новый 2EX-файл.
    public let twoEX: Data
}

/// Readback-модель ANLZ-файла.
public struct PioneerANLZReadback: Equatable {
    /// Длина PMAI header.
    public let headerLength: UInt32

    /// Длина файла из PMAI header.
    public let fileLength: UInt32

    /// Секции после PMAI header.
    public let sections: [PioneerANLZSection]

    /// Первый PPTH путь, если он есть.
    public var ppThPath: String? {
        sections.first { $0.fourCC == "PPTH" }?.utf16BEStringBody
    }
}

/// Readback-модель секции ANLZ.
public struct PioneerANLZSection: Equatable {
    /// FourCC секции.
    public let fourCC: String

    /// Длина header секции.
    public let headerLength: UInt32

    /// Полная длина секции.
    public let length: UInt32

    /// Тело секции.
    public let body: Data

    /// Декодирует тело как UTF-16BE строку.
    public var utf16BEStringBody: String? {
        var units: [UInt16] = []
        var index = body.startIndex
        while index + 1 < body.endIndex {
            let high = UInt16(body[index]) << 8
            let low = UInt16(body[index + 1])
            let unit = high | low
            if unit == 0 { break }
            units.append(unit)
            index += 2
        }
        return String(decoding: units, as: UTF16.self)
    }
}

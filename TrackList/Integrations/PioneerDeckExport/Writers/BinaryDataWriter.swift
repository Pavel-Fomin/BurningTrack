//
//  BinaryDataWriter.swift
//  TrackList
//
//  Низкоуровневая запись бинарных полей для Pioneer Export writer.
//

import Foundation

/// Небольшой helper для явной записи endian-зависимых бинарных структур.
struct BinaryDataWriter {
    /// Накопленный бинарный буфер.
    private(set) var data = Data()

    /// Текущая длина буфера.
    var count: Int { data.count }

    /// Добавляет один байт.
    mutating func appendUInt8(_ value: UInt8) {
        data.append(value)
    }

    /// Добавляет UInt16 в little-endian.
    mutating func appendUInt16LE(_ value: UInt16) {
        appendFixedWidth(value.littleEndian)
    }

    /// Добавляет UInt32 в little-endian.
    mutating func appendUInt32LE(_ value: UInt32) {
        appendFixedWidth(value.littleEndian)
    }

    /// Добавляет UInt16 в big-endian.
    mutating func appendUInt16BE(_ value: UInt16) {
        appendFixedWidth(value.bigEndian)
    }

    /// Добавляет UInt32 в big-endian.
    mutating func appendUInt32BE(_ value: UInt32) {
        appendFixedWidth(value.bigEndian)
    }

    /// Добавляет сырые байты Data.
    mutating func appendData(_ value: Data) {
        data.append(value)
    }

    /// Добавляет ASCII-строку без padding.
    mutating func appendASCII(_ string: String) {
        data.append(Data(string.utf8))
    }

    /// Добавляет ASCII-строку фиксированной длины с нулевым заполнением.
    mutating func appendFixedASCII(_ string: String, length: Int) {
        let bytes = Array(string.utf8.prefix(length))
        data.append(contentsOf: bytes)
        appendZeroes(length - bytes.count)
    }

    /// Добавляет length-prefixed UTF-8 строку для scaffold/readback-структур.
    mutating func appendLengthPrefixedUTF8(_ string: String) {
        let encoded = Data(string.utf8)
        appendUInt32LE(UInt32(encoded.count))
        appendData(encoded)
    }

    /// Добавляет UTF-16BE строку для PPTH-секции ANLZ.
    mutating func appendUTF16BE(_ string: String, terminated: Bool) {
        for unit in string.utf16 {
            appendUInt16BE(unit)
        }

        if terminated {
            appendUInt16BE(0)
        }
    }

    /// Добавляет нулевые байты.
    mutating func appendZeroes(_ count: Int) {
        guard count > 0 else { return }
        data.append(contentsOf: repeatElement(UInt8(0), count: count))
    }

    /// Дополняет буфер до фиксированной длины.
    mutating func pad(toLength length: Int) {
        appendZeroes(max(0, length - data.count))
    }

    /// Дополняет буфер до кратности указанного размера.
    mutating func pad(toMultipleOf multiple: Int) {
        guard multiple > 0 else { return }
        let remainder = data.count % multiple
        if remainder != 0 {
            appendZeroes(multiple - remainder)
        }
    }

    /// Перезаписывает UInt32 big-endian по известному offset.
    mutating func patchUInt32BE(_ value: UInt32, at offset: Int) {
        let bytes = withUnsafeBytes(of: value.bigEndian) { Data($0) }
        data.replaceSubrange(offset..<(offset + 4), with: bytes)
    }

    /// Перезаписывает UInt32 little-endian по известному offset.
    mutating func patchUInt32LE(_ value: UInt32, at offset: Int) {
        let bytes = withUnsafeBytes(of: value.littleEndian) { Data($0) }
        data.replaceSubrange(offset..<(offset + 4), with: bytes)
    }

    /// Общая запись fixed-width значения.
    private mutating func appendFixedWidth<T>(_ value: T) {
        var localValue = value
        withUnsafeBytes(of: &localValue) { bytes in
            data.append(contentsOf: bytes)
        }
    }
}

/// Минимальный reader для readback-тестов бинарных building blocks.
struct BinaryDataReader {
    /// Исходный бинарный буфер.
    private let data: Data

    /// Текущая позиция чтения.
    private(set) var offset: Int = 0

    /// Создаёт reader поверх Data.
    init(data: Data) {
        self.data = data
    }

    /// Проверяет достижение конца буфера.
    var isAtEnd: Bool {
        offset >= data.count
    }

    /// Читает фиксированное количество байтов.
    mutating func readData(count: Int) throws -> Data {
        guard offset + count <= data.count else {
            throw PioneerDeckExportError.invalidBinaryLayout("Не хватает байтов для чтения \(count).")
        }

        let result = data.subdata(in: offset..<(offset + count))
        offset += count
        return result
    }

    /// Читает UInt32 little-endian.
    mutating func readUInt32LE() throws -> UInt32 {
        let bytes = try readData(count: 4)
        return UInt32(bytes[bytes.startIndex])
            | (UInt32(bytes[bytes.startIndex + 1]) << 8)
            | (UInt32(bytes[bytes.startIndex + 2]) << 16)
            | (UInt32(bytes[bytes.startIndex + 3]) << 24)
    }

    /// Читает UInt32 big-endian.
    mutating func readUInt32BE() throws -> UInt32 {
        let bytes = try readData(count: 4)
        return (UInt32(bytes[bytes.startIndex]) << 24)
            | (UInt32(bytes[bytes.startIndex + 1]) << 16)
            | (UInt32(bytes[bytes.startIndex + 2]) << 8)
            | UInt32(bytes[bytes.startIndex + 3])
    }

    /// Читает length-prefixed UTF-8 строку.
    mutating func readLengthPrefixedUTF8() throws -> String {
        let length = Int(try readUInt32LE())
        let bytes = try readData(count: length)
        guard let string = String(data: bytes, encoding: .utf8) else {
            throw PioneerDeckExportError.invalidBinaryLayout("UTF-8 строка не декодируется.")
        }
        return string
    }

    /// Перемещает offset на абсолютную позицию.
    mutating func seek(to newOffset: Int) throws {
        guard newOffset >= 0 && newOffset <= data.count else {
            throw PioneerDeckExportError.invalidBinaryLayout("Offset \(newOffset) за пределами буфера.")
        }
        offset = newOffset
    }
}

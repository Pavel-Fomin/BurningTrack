//
//  PioneerDeviceSQLStringWriter.swift
//  TrackList
//
//  Запись строк DeviceSQL из rekordbox_pdb.ksy.
//

import Foundation

/// Кодирует строки в три подтверждённых DeviceSQL-варианта: short ASCII, long ASCII, UTF-16LE.
enum PioneerDeviceSQLStringWriter {
    /// Записывает строку в формате device_sql_string.
    static func write(_ string: String) throws -> Data {
        if isASCII(string) {
            let ascii = Data(string.utf8)
            if ascii.count <= 126 {
                return makeShortASCII(ascii)
            }
            return try makeLongASCII(ascii)
        }

        return try makeUTF16LE(string)
    }

    /// Проверяет, можно ли сохранить строку как ASCII без потери символов.
    private static func isASCII(_ string: String) -> Bool {
        string.unicodeScalars.allSatisfy { $0.value <= 0x7f }
    }

    /// Пишет short ASCII: первый байт хранит длину всего поля и low-bit маркер.
    private static func makeShortASCII(_ bytes: Data) -> Data {
        var writer = BinaryDataWriter()
        writer.appendUInt8(UInt8((bytes.count + 1) * 2 + 1))
        writer.appendData(bytes)
        return writer.data
    }

    /// Пишет long ASCII с kind 0x40.
    private static func makeLongASCII(_ bytes: Data) throws -> Data {
        guard bytes.count <= Int(UInt16.max) - 4 else {
            throw PioneerDeckExportError.invalidBinaryLayout("DeviceSQL ASCII-строка слишком длинная.")
        }

        var writer = BinaryDataWriter()
        writer.appendUInt8(0x40)
        writer.appendUInt16LE(UInt16(bytes.count + 4))
        writer.appendUInt8(0)
        writer.appendData(bytes)
        return writer.data
    }

    /// Пишет UTF-16LE с kind 0x90, как описано в rekordbox_pdb.ksy.
    private static func makeUTF16LE(_ string: String) throws -> Data {
        let byteCount = string.utf16.count * 2
        guard byteCount <= Int(UInt16.max) - 4 else {
            throw PioneerDeckExportError.invalidBinaryLayout("DeviceSQL UTF-16LE-строка слишком длинная.")
        }

        var writer = BinaryDataWriter()
        writer.appendUInt8(0x90)
        writer.appendUInt16LE(UInt16(byteCount + 4))
        writer.appendUInt8(0)
        for unit in string.utf16 {
            writer.appendUInt16LE(unit)
        }
        return writer.data
    }
}

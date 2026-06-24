//
//  PioneerDeviceSQLRow.swift
//  TrackList
//
//  Сериализация строк таблиц DeviceSQL export.pdb.
//

import Foundation

/// Строки readback-дампа DeviceSQL.
public enum PioneerDeviceSQLReadbackRow: Equatable, Sendable {
    /// Строка tracks.
    case track(PioneerDeviceSQLReadbackTrack)

    /// Строка playlist_tree.
    case playlistTree(PioneerDeviceSQLReadbackPlaylist)

    /// Строка playlist_entries.
    case playlistEntry(PioneerDeviceSQLReadbackPlaylistEntry)

    /// Строка colors.
    case color(PioneerDeviceSQLReadbackColor)
}

/// Readback-строка tracks.
public struct PioneerDeviceSQLReadbackTrack: Equatable, Sendable {
    /// Id трека.
    public let id: UInt32

    /// Название трека.
    public let title: String

    /// Длительность в секундах.
    public let durationSeconds: UInt16

    /// Sample rate из track_row.
    public let sampleRate: UInt32

    /// Размер файла из track_row.
    public let fileSize: UInt32

    /// Bit depth из track_row.
    public let sampleDepth: UInt16

    /// Bitrate из track_row.
    public let bitrate: UInt32

    /// BPM * 100 из track_row.
    public let tempoX100: UInt32

    /// Имя аудиофайла.
    public let fileName: String

    /// Путь аудиофайла внутри USB export.
    public let filePath: String

    /// Путь ANLZ DAT-файла.
    public let analyzePath: String

    /// Флаг публичности KUVO из track_row.
    public let kuvoPublic: String

    /// Флаг автозагрузки hot cues из track_row.
    public let autoloadHotCues: String

    /// Дата анализа из track_row.
    public let analyzeDate: String

    /// Id цветовой метки.
    public let colorId: UInt8
}

/// Readback-строка playlist_tree.
public struct PioneerDeviceSQLReadbackPlaylist: Equatable, Sendable {
    /// Id родительской папки.
    public let parentId: UInt32

    /// Sort order из строки playlist_tree.
    public let sortOrder: UInt32

    /// Id плейлиста.
    public let id: UInt32

    /// Признак папки.
    public let isFolder: Bool

    /// Имя плейлиста.
    public let name: String
}

/// Readback-строка playlist_entries.
public struct PioneerDeviceSQLReadbackPlaylistEntry: Equatable, Sendable {
    /// Позиция внутри плейлиста.
    public let entryIndex: UInt32

    /// Id трека.
    public let trackId: UInt32

    /// Id плейлиста.
    public let playlistId: UInt32
}

/// Readback-строка colors.
public struct PioneerDeviceSQLReadbackColor: Equatable, Sendable {
    /// Id цвета.
    public let id: UInt16

    /// Имя цвета.
    public let name: String
}

/// Сериализует строки таблиц, входящих в первый DeviceSQL export.pdb.
enum PioneerDeviceSQLRowWriter {
    /// Длина фиксированной части track_row до массива строк.
    private static let trackFixedLength = 136

    /// Количество строковых offset-полей track_row по rekordbox_pdb.ksy.
    private static let trackStringCount = 21

    /// Пишет строку tracks.
    static func makeTrackRow(_ track: PioneerDeckTrack) throws -> Data {
        var strings = Array(repeating: "", count: trackStringCount)
        // rekordbox reference стабильно пишет эти флаги как строковые "ON".
        strings[6] = "ON"
        strings[7] = "ON"
        strings[14] = PlaceholderUSBANLZPathStrategy.placeholderAnalyzePathForPDB(trackId: track.id)
        // Дату анализа пишем только если caller передал подтверждённое значение.
        strings[15] = track.analyzeDate ?? ""
        strings[17] = track.title
        strings[19] = track.fileName
        strings[20] = track.usbRelativePath

        let encodedStrings = try strings.map { try PioneerDeviceSQLStringWriter.write($0) }
        var offsets: [UInt16] = []
        var cursor = trackFixedLength
        for stringData in encodedStrings {
            guard cursor <= Int(UInt16.max) else {
                throw PioneerDeckExportError.invalidBinaryLayout("Offset строки track_row не помещается в UInt16.")
            }
            offsets.append(UInt16(cursor))
            cursor += stringData.count
        }

        var writer = BinaryDataWriter()
        writer.appendUInt16LE(0x24)
        writer.appendUInt16LE(0) // TODO(DeviceSQL): выяснить index_shift из rekordbox_pdb.ksy на реальных export.pdb.
        writer.appendUInt32LE(0) // TODO(DeviceSQL): выяснить bitmask track_row.
        writer.appendUInt32LE(track.sampleRate ?? 0)
        writer.appendUInt32LE(0)
        writer.appendUInt32LE(track.fileSize ?? 0)
        writer.appendUInt32LE(0)
        writer.appendUInt16LE(19048)
        writer.appendUInt16LE(30967)
        writer.appendUInt32LE(0)
        writer.appendUInt32LE(0)
        writer.appendUInt32LE(0)
        writer.appendUInt32LE(0)
        writer.appendUInt32LE(0)
        writer.appendUInt32LE(track.bitrate ?? 0)
        writer.appendUInt32LE(0)
        writer.appendUInt32LE(track.tempoX100 ?? 0)
        writer.appendUInt32LE(0)
        writer.appendUInt32LE(0)
        writer.appendUInt32LE(0) // TODO(DeviceSQL): таблица artists не входит в первый scope, поэтому artist_id пока 0.
        writer.appendUInt32LE(track.id)
        writer.appendUInt16LE(0)
        writer.appendUInt16LE(0)
        writer.appendUInt16LE(0)
        writer.appendUInt16LE(track.sampleDepth ?? 0)
        writer.appendUInt16LE(UInt16(clamping: track.durationSeconds))
        writer.appendUInt16LE(41)
        writer.appendUInt8(UInt8(clamping: track.colorId))
        writer.appendUInt8(0)
        writer.appendUInt16LE(1)
        writer.appendUInt16LE(3)
        for offset in offsets {
            writer.appendUInt16LE(offset)
        }
        for stringData in encodedStrings {
            writer.appendData(stringData)
        }
        return writer.data
    }

    /// Пишет строку playlist_tree для обычного плейлиста без папок.
    static func makePlaylistTreeRow(_ playlist: PioneerDeckPlaylist, sortOrder: UInt32) throws -> Data {
        var writer = BinaryDataWriter()
        writer.appendUInt32LE(0)
        writer.appendZeroes(4) // TODO(DeviceSQL): неизвестное поле playlist_tree_row из ksy.
        writer.appendUInt32LE(sortOrder)
        writer.appendUInt32LE(playlist.id)
        writer.appendUInt32LE(0)
        writer.appendData(try PioneerDeviceSQLStringWriter.write(playlist.name))
        // rekordbox выравнивает строки playlist_tree до 4 байт; ksy читает строку без padding.
        writer.pad(toMultipleOf: 4)
        return writer.data
    }

    /// Пишет строку playlist_entries с порядком трека внутри плейлиста.
    static func makePlaylistEntryRow(playlistId: UInt32, entry: PioneerDeckPlaylistEntry) -> Data {
        var writer = BinaryDataWriter()
        writer.appendUInt32LE(entry.position)
        writer.appendUInt32LE(entry.trackId)
        writer.appendUInt32LE(playlistId)
        return writer.data
    }

    /// Пишет строку colors по структуре color_row из ksy.
    static func makeColorRow(_ color: PioneerDeckColor) throws -> Data {
        var writer = BinaryDataWriter()
        writer.appendUInt32LE(0)
        // TODO(DeviceSQL): offset 0x04 не назван в ksy; reference для default colors хранит здесь копию color id.
        writer.appendUInt8(UInt8(clamping: color.id))
        writer.appendUInt16LE(UInt16(clamping: color.id))
        writer.appendUInt8(0)
        writer.appendData(try PioneerDeviceSQLStringWriter.write(color.name))
        // rekordbox выравнивает color_row до 4 байт; ksy читает строку без padding.
        writer.pad(toMultipleOf: 4)
        return writer.data
    }
}

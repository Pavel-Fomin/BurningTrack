//
//  PioneerPDBWriter.swift
//  TrackList
//
//  Фасад записи legacy DeviceSQL export.pdb.
//

import Foundation

/// Пишет legacy DeviceSQL export.pdb через отдельный DeviceSQL writer-слой.
public struct PioneerPDBWriter {
    /// Размер страницы из каноничного документа.
    public static let pageSize = 4_096

    /// Magic явно отделяет scaffold от настоящего DeviceSQL.
    private static let scaffoldMagic = "BTPDB001"

    /// Writer настоящего DeviceSQL export.pdb.
    private let deviceSQLWriter: PioneerDeviceSQLWriter

    /// Создаёт writer.
    public init(deviceSQLWriter: PioneerDeviceSQLWriter = PioneerDeviceSQLWriter()) {
        self.deviceSQLWriter = deviceSQLWriter
    }

    /// Возвращает бинарный DeviceSQL export.pdb.
    public func write(export: PioneerDeckExport) throws -> Data {
        try deviceSQLWriter.write(export: export)
    }

    /// Возвращает прежний scaffold export.pdb для сравнения с новым DeviceSQL writer.
    public func writeScaffold(export: PioneerDeckExport) throws -> Data {
        try export.validate()

        let tables = [
            makeTracksTable(export.tracks),
            makePlaylistTreeTable(export.playlists),
            makePlaylistEntriesTable(export.playlists),
            makeColorsTable(export.colors)
        ]

        return try makeScaffold(kind: "export", tables: tables)
    }

    /// Читает scaffold обратно для unit/readback-тестов.
    public static func readScaffold(from data: Data) throws -> PioneerPDBReadback {
        try PioneerPDBScaffoldCodec.read(from: data, expectedMagic: scaffoldMagic)
    }

    /// Таблица tracks: официальный type=0 подтверждён каноничным документом.
    private func makeTracksTable(_ tracks: [PioneerDeckTrack]) -> PioneerPDBScaffoldTable {
        let rows = tracks.sorted { $0.id < $1.id }.map { track -> Data in
            var writer = BinaryDataWriter()
            writer.appendUInt32LE(track.id)
            writer.appendLengthPrefixedUTF8(track.sourceTrackId.uuidString)
            writer.appendLengthPrefixedUTF8(track.title)
            writer.appendLengthPrefixedUTF8(track.artist)
            writer.appendUInt32LE(track.durationSeconds)
            writer.appendLengthPrefixedUTF8(track.fileName)
            writer.appendLengthPrefixedUTF8(track.usbRelativePath)
            writer.appendLengthPrefixedUTF8(PlaceholderUSBANLZPathStrategy.placeholderAnalyzePathForPDB(trackId: track.id))
            writer.appendUInt32LE(track.colorId)
            return writer.data
        }

        return PioneerPDBScaffoldTable(name: "tracks", declaredType: 0, rows: rows)
    }

    /// Таблица playlist_tree: type не указан в локальном документе, поэтому scaffold не выдумывает официальный type.
    private func makePlaylistTreeTable(_ playlists: [PioneerDeckPlaylist]) -> PioneerPDBScaffoldTable {
        let rows = playlists.sorted { $0.id < $1.id }.map { playlist -> Data in
            var writer = BinaryDataWriter()
            writer.appendUInt32LE(playlist.id)
            writer.appendLengthPrefixedUTF8(playlist.sourcePlaylistId.uuidString)
            writer.appendLengthPrefixedUTF8(playlist.name)
            return writer.data
        }

        return PioneerPDBScaffoldTable(name: "playlist_tree", declaredType: nil, rows: rows)
    }

    /// Таблица playlist_entries хранит playlist_id, track_id и позицию без потери порядка.
    private func makePlaylistEntriesTable(_ playlists: [PioneerDeckPlaylist]) -> PioneerPDBScaffoldTable {
        let rows = playlists
            .sorted { $0.id < $1.id }
            .flatMap { playlist in
                playlist.entries.sorted { $0.position < $1.position }.map { entry -> Data in
                    var writer = BinaryDataWriter()
                    writer.appendUInt32LE(playlist.id)
                    writer.appendUInt32LE(entry.trackId)
                    writer.appendUInt32LE(entry.position)
                    return writer.data
                }
            }

        return PioneerPDBScaffoldTable(name: "playlist_entries", declaredType: nil, rows: rows)
    }

    /// Таблица colors: официальный type=6 подтверждён каноничным документом.
    private func makeColorsTable(_ colors: [PioneerDeckColor]) -> PioneerPDBScaffoldTable {
        let rows = colors.sorted { $0.id < $1.id }.map { color -> Data in
            var writer = BinaryDataWriter()
            writer.appendUInt32LE(color.id)
            writer.appendLengthPrefixedUTF8(color.name)
            writer.appendUInt8(color.red)
            writer.appendUInt8(color.green)
            writer.appendUInt8(color.blue)
            return writer.data
        }

        return PioneerPDBScaffoldTable(name: "colors", declaredType: 6, rows: rows)
    }

    /// Собирает общий scaffold с 4096-байтным header page и payload-страницами.
    private func makeScaffold(kind: String, tables: [PioneerPDBScaffoldTable]) throws -> Data {
        try PioneerPDBScaffoldCodec.write(
            magic: Self.scaffoldMagic,
            kind: kind,
            pageSize: Self.pageSize,
            tables: tables
        )
    }
}

/// Readback-модель scaffold-файла.
public struct PioneerPDBReadback: Equatable {
    /// Логический вид файла: export или exportExt.
    public let kind: String

    /// Размер страницы из header.
    public let pageSize: UInt32

    /// Таблицы по имени.
    public let tables: [String: PioneerPDBReadbackTable]

    /// Раскодированные entries для проверки порядка плейлистов.
    public var playlistEntries: [PioneerPDBReadbackPlaylistEntry] {
        guard let table = tables["playlist_entries"] else { return [] }
        return table.rows.compactMap { row in
            guard row.count == 12 else { return nil }
            var reader = BinaryDataReader(data: row)
            return try? PioneerPDBReadbackPlaylistEntry(
                playlistId: reader.readUInt32LE(),
                trackId: reader.readUInt32LE(),
                position: reader.readUInt32LE()
            )
        }
    }
}

/// Readback-таблица scaffold-файла.
public struct PioneerPDBReadbackTable: Equatable {
    /// Имя таблицы.
    public let name: String

    /// Официальный type, если он подтверждён документом.
    public let declaredType: UInt32?

    /// Сырые строки таблицы.
    public let rows: [Data]
}

/// Readback-строка playlist_entries.
public struct PioneerPDBReadbackPlaylistEntry: Equatable {
    /// Id плейлиста.
    public let playlistId: UInt32

    /// Id трека.
    public let trackId: UInt32

    /// Позиция внутри плейлиста.
    public let position: UInt32
}

/// Внутренняя таблица scaffold-писателя.
struct PioneerPDBScaffoldTable {
    /// Имя таблицы.
    let name: String

    /// Подтверждённый type DeviceSQL или nil, если документ его не задаёт.
    let declaredType: UInt32?

    /// Сырые строки таблицы.
    let rows: [Data]
}

/// Общий codec для export.pdb и exportExt.pdb scaffold-файлов.
enum PioneerPDBScaffoldCodec {
    /// Значение для неизвестного официального table type.
    private static let unknownType: UInt32 = UInt32.max

    /// Пишет scaffold с фиксированной первой страницей.
    static func write(
        magic: String,
        kind: String,
        pageSize: Int,
        tables: [PioneerPDBScaffoldTable]
    ) throws -> Data {
        var payload = BinaryDataWriter()
        var descriptors: [(table: PioneerPDBScaffoldTable, offset: UInt32, length: UInt32)] = []

        for table in tables {
            let start = UInt32(payload.count + pageSize)
            let tableData = makeTablePayload(table.rows)
            payload.appendData(tableData)
            descriptors.append((table: table, offset: start, length: UInt32(tableData.count)))
        }

        var header = BinaryDataWriter()
        header.appendFixedASCII(magic, length: 8)
        header.appendUInt32LE(UInt32(pageSize))
        header.appendLengthPrefixedUTF8(kind)
        header.appendUInt32LE(UInt32(tables.count))
        header.appendUInt32LE(1)

        for descriptor in descriptors {
            header.appendFixedASCII(descriptor.table.name, length: 32)
            header.appendUInt32LE(descriptor.table.declaredType ?? unknownType)
            header.appendUInt32LE(UInt32(descriptor.table.rows.count))
            header.appendUInt32LE(descriptor.offset)
            header.appendUInt32LE(descriptor.length)
        }

        guard header.count <= pageSize else {
            throw PioneerDeckExportError.invalidBinaryLayout("Scaffold header не помещается в страницу.")
        }

        header.pad(toLength: pageSize)
        header.appendData(payload.data)
        header.pad(toMultipleOf: pageSize)
        return header.data
    }

    /// Читает scaffold обратно и проверяет magic/page/table payload.
    static func read(from data: Data, expectedMagic: String) throws -> PioneerPDBReadback {
        var reader = BinaryDataReader(data: data)
        let magic = try String(data: reader.readData(count: 8), encoding: .utf8) ?? ""
        guard magic == expectedMagic else {
            throw PioneerDeckExportError.invalidBinaryLayout("Неожиданный magic scaffold PDB.")
        }

        let pageSize = try reader.readUInt32LE()
        let kind = try reader.readLengthPrefixedUTF8()
        let tableCount = try reader.readUInt32LE()
        _ = try reader.readUInt32LE()

        var descriptors: [(name: String, type: UInt32?, rowCount: UInt32, offset: UInt32, length: UInt32)] = []
        for _ in 0..<tableCount {
            let nameData = try reader.readData(count: 32)
            let name = String(data: nameData.prefix { $0 != 0 }, encoding: .utf8) ?? ""
            let rawType = try reader.readUInt32LE()
            let rowCount = try reader.readUInt32LE()
            let offset = try reader.readUInt32LE()
            let length = try reader.readUInt32LE()
            descriptors.append((name: name, type: rawType == unknownType ? nil : rawType, rowCount: rowCount, offset: offset, length: length))
        }

        let tables = try descriptors.reduce(into: [String: PioneerPDBReadbackTable]()) { partial, descriptor in
            let start = Int(descriptor.offset)
            let end = start + Int(descriptor.length)
            guard start >= 0, end <= data.count else {
                throw PioneerDeckExportError.invalidBinaryLayout("Payload таблицы \(descriptor.name) за пределами файла.")
            }

            let rows = try readTablePayload(data.subdata(in: start..<end), expectedRows: descriptor.rowCount)
            partial[descriptor.name] = PioneerPDBReadbackTable(
                name: descriptor.name,
                declaredType: descriptor.type,
                rows: rows
            )
        }

        return PioneerPDBReadback(kind: kind, pageSize: pageSize, tables: tables)
    }

    /// Кодирует строки одной таблицы.
    private static func makeTablePayload(_ rows: [Data]) -> Data {
        var writer = BinaryDataWriter()
        writer.appendUInt32LE(UInt32(rows.count))
        for row in rows {
            writer.appendUInt32LE(UInt32(row.count))
            writer.appendData(row)
        }
        return writer.data
    }

    /// Декодирует строки одной таблицы.
    private static func readTablePayload(_ data: Data, expectedRows: UInt32) throws -> [Data] {
        var reader = BinaryDataReader(data: data)
        let rowCount = try reader.readUInt32LE()
        guard rowCount == expectedRows else {
            throw PioneerDeckExportError.invalidBinaryLayout("Row count таблицы не совпадает с descriptor.")
        }

        var rows: [Data] = []
        for _ in 0..<rowCount {
            let rowLength = Int(try reader.readUInt32LE())
            rows.append(try reader.readData(count: rowLength))
        }

        return rows
    }
}

//
//  PioneerDeviceSQLReadbackInspector.swift
//  TrackList
//
//  Readback-инспектор для собственного DeviceSQL export.pdb.
//

import Foundation

/// Структурный дамп DeviceSQL export.pdb для unit/golden тестов.
public struct PioneerDeviceSQLReadbackDump: Equatable, Sendable {
    /// Header первой страницы.
    public let header: PioneerDeviceSQLReadbackHeader

    /// Таблицы по имени.
    public let tables: [String: PioneerDeviceSQLReadbackTable]

    /// Строки playlist_entries в порядке чтения из row index.
    public var playlistEntries: [PioneerDeviceSQLReadbackPlaylistEntry] {
        tables["playlist_entries"]?.playlistEntries ?? []
    }

    /// Строки playlist_entries в семантическом порядке DeviceSQL: playlist_id, затем entry_index.
    public var playlistEntriesInPlaylistOrder: [PioneerDeviceSQLReadbackPlaylistEntry] {
        playlistEntries.sorted {
            if $0.playlistId != $1.playlistId {
                return $0.playlistId < $1.playlistId
            }
            return $0.entryIndex < $1.entryIndex
        }
    }
}

/// Readback header первой страницы DeviceSQL.
public struct PioneerDeviceSQLReadbackHeader: Equatable, Sendable {
    /// Первое неизвестное поле.
    public let unknownSignature: UInt32

    /// Размер страницы.
    public let pageSize: UInt32

    /// Количество table pointers.
    public let tableCount: UInt32

    /// Индекс страницы сразу за концом файла.
    public let nextUnusedPage: UInt32

    /// Неизвестное поле header offset 0x10.
    public let unknown0x10: UInt32

    /// Sequence базы.
    public let sequence: UInt32
}

/// Readback table pointer и прочитанные строки.
public struct PioneerDeviceSQLReadbackTable: Equatable, Sendable {
    /// Имя таблицы.
    public let name: String

    /// Type из page_type.
    public let type: UInt32

    /// Candidate-страница для empty/free chain из descriptor.
    public let emptyCandidate: UInt32

    /// Первая страница цепочки.
    public let firstPage: UInt32

    /// Последняя страница цепочки.
    public let lastPage: UInt32

    /// Страницы таблицы.
    public let pages: [PioneerDeviceSQLReadbackPage]

    /// Все строки data-страниц.
    public let rows: [PioneerDeviceSQLReadbackRow]

    /// Удобный доступ к tracks.
    public var tracks: [PioneerDeviceSQLReadbackTrack] {
        rows.compactMap {
            if case let .track(track) = $0 { return track }
            return nil
        }
    }

    /// Удобный доступ к playlist_tree.
    public var playlists: [PioneerDeviceSQLReadbackPlaylist] {
        rows.compactMap {
            if case let .playlistTree(playlist) = $0 { return playlist }
            return nil
        }
    }

    /// Удобный доступ к playlist_entries.
    public var playlistEntries: [PioneerDeviceSQLReadbackPlaylistEntry] {
        rows.compactMap {
            if case let .playlistEntry(entry) = $0 { return entry }
            return nil
        }
    }

    /// Удобный доступ к colors.
    public var colors: [PioneerDeviceSQLReadbackColor] {
        rows.compactMap {
            if case let .color(color) = $0 { return color }
            return nil
        }
    }
}

/// Readback одной страницы таблицы.
public struct PioneerDeviceSQLReadbackPage: Equatable, Sendable {
    /// Индекс страницы.
    public let pageIndex: UInt32

    /// Type страницы.
    public let type: UInt32

    /// Следующая страница цепочки.
    public let nextPage: UInt32

    /// Количество выделенных row offsets.
    public let numRowOffsets: UInt16

    /// Количество валидных строк.
    public let numRows: UInt16

    /// Page flags из ksy.
    public let pageFlags: UInt8

    /// Свободный размер heap.
    public let freeSize: UInt16

    /// Использованный размер heap.
    public let usedSize: UInt16

    /// Строки, прочитанные через row index и bitmap.
    public let rows: [PioneerDeviceSQLReadbackRow]
}

/// Читает собственный DeviceSQL-файл и проверяет header/page/row-index layout.
public enum PioneerDeviceSQLReadbackInspector {
    /// Строит структурный дамп export.pdb.
    public static func inspect(data: Data) throws -> PioneerDeviceSQLReadbackDump {
        let header = try readHeader(data)
        let pageSize = Int(header.pageSize)
        guard pageSize == PioneerDeviceSQLHeader.pageSize else {
            throw PioneerDeckExportError.invalidBinaryLayout("DeviceSQL page size должен быть 4096.")
        }
        guard data.count % pageSize == 0 else {
            throw PioneerDeckExportError.invalidBinaryLayout("DeviceSQL файл не кратен размеру страницы.")
        }

        let descriptors = try readTableDescriptors(data, tableCount: Int(header.tableCount))
        var tables: [String: PioneerDeviceSQLReadbackTable] = [:]
        for descriptor in descriptors {
            let table = try readTable(data, descriptor: descriptor, pageSize: pageSize)
            tables[table.name] = table
        }

        return PioneerDeviceSQLReadbackDump(header: header, tables: tables)
    }

    /// Читает header первой страницы.
    private static func readHeader(_ data: Data) throws -> PioneerDeviceSQLReadbackHeader {
        guard data.count >= PioneerDeviceSQLHeader.tableDirectoryOffset else {
            throw PioneerDeckExportError.invalidBinaryLayout("DeviceSQL header короче 0x1c.")
        }
        let gap = try data.pioneerReadData(in: 0x18..<0x1c)
        guard gap == Data(repeating: 0, count: 4) else {
            throw PioneerDeckExportError.invalidBinaryLayout("DeviceSQL header gap должен быть нулевым.")
        }

        return PioneerDeviceSQLReadbackHeader(
            unknownSignature: try data.pioneerUInt32LE(at: 0x00),
            pageSize: try data.pioneerUInt32LE(at: 0x04),
            tableCount: try data.pioneerUInt32LE(at: 0x08),
            nextUnusedPage: try data.pioneerUInt32LE(at: 0x0c),
            unknown0x10: try data.pioneerUInt32LE(at: 0x10),
            sequence: try data.pioneerUInt32LE(at: 0x14)
        )
    }

    /// Читает table pointers из header.
    private static func readTableDescriptors(
        _ data: Data,
        tableCount: Int
    ) throws -> [PioneerDeviceSQLTableDescriptor] {
        try (0..<tableCount).map { index in
            let offset = PioneerDeviceSQLHeader.tableDirectoryOffset + index * PioneerDeviceSQLHeader.tableDescriptorSize
            let rawType = try data.pioneerUInt32LE(at: offset)
            guard let type = PioneerDeviceSQLTableType(rawValue: rawType) else {
                throw PioneerDeckExportError.invalidBinaryLayout("Неподдержанный table type \(rawType).")
            }
            return PioneerDeviceSQLTableDescriptor(
                type: type,
                emptyCandidate: try data.pioneerUInt32LE(at: offset + 0x04),
                firstPage: try data.pioneerUInt32LE(at: offset + 0x08),
                lastPage: try data.pioneerUInt32LE(at: offset + 0x0c),
                rowCount: 0
            )
        }
    }

    /// Читает цепочку страниц одной таблицы.
    private static func readTable(
        _ data: Data,
        descriptor: PioneerDeviceSQLTableDescriptor,
        pageSize: Int
    ) throws -> PioneerDeviceSQLReadbackTable {
        var pages: [PioneerDeviceSQLReadbackPage] = []
        var rows: [PioneerDeviceSQLReadbackRow] = []
        var visited = Set<UInt32>()
        var currentPageIndex = descriptor.firstPage

        while true {
            guard visited.insert(currentPageIndex).inserted else {
                throw PioneerDeckExportError.invalidBinaryLayout("Зацикленная цепочка страниц \(descriptor.type.tableName).")
            }

            let page = try readPage(
                data,
                pageIndex: currentPageIndex,
                expectedType: descriptor.type,
                pageSize: pageSize
            )
            pages.append(page)
            rows.append(contentsOf: page.rows)

            if currentPageIndex == descriptor.lastPage {
                break
            }
            currentPageIndex = page.nextPage
        }

        return PioneerDeviceSQLReadbackTable(
            name: descriptor.type.tableName,
            type: descriptor.type.rawValue,
            emptyCandidate: descriptor.emptyCandidate,
            firstPage: descriptor.firstPage,
            lastPage: descriptor.lastPage,
            pages: pages,
            rows: rows
        )
    }

    /// Читает одну страницу таблицы.
    private static func readPage(
        _ data: Data,
        pageIndex: UInt32,
        expectedType: PioneerDeviceSQLTableType,
        pageSize: Int
    ) throws -> PioneerDeviceSQLReadbackPage {
        let pageOffset = Int(pageIndex) * pageSize
        guard pageOffset + pageSize <= data.count else {
            throw PioneerDeckExportError.invalidBinaryLayout("Страница \(pageIndex) за пределами DeviceSQL файла.")
        }
        guard try data.pioneerReadData(in: pageOffset..<(pageOffset + 4)) == Data(repeating: 0, count: 4) else {
            throw PioneerDeckExportError.invalidBinaryLayout("Gap страницы \(pageIndex) должен быть нулевым.")
        }

        let storedPageIndex = try data.pioneerUInt32LE(at: pageOffset + 0x04)
        let rawType = try data.pioneerUInt32LE(at: pageOffset + 0x08)
        guard storedPageIndex == pageIndex, rawType == expectedType.rawValue else {
            throw PioneerDeckExportError.invalidBinaryLayout("Page header не совпадает с table descriptor.")
        }

        let packedRows = try data.pioneerUInt24LE(at: pageOffset + 0x18)
        let numRowOffsets = UInt16(packedRows & 0x1fff)
        let numRows = UInt16((packedRows >> 13) & 0x07ff)
        let pageFlags = try data.pioneerUInt8(at: pageOffset + 0x1b)
        let rows = try readRows(
            data,
            pageOffset: pageOffset,
            pageSize: pageSize,
            tableType: expectedType,
            numRowOffsets: Int(numRowOffsets),
            pageFlags: pageFlags
        )
        guard rows.count == Int(numRows) else {
            throw PioneerDeckExportError.invalidBinaryLayout("Количество строк страницы \(pageIndex) не совпадает с bitmap.")
        }

        return PioneerDeviceSQLReadbackPage(
            pageIndex: pageIndex,
            type: rawType,
            nextPage: try data.pioneerUInt32LE(at: pageOffset + 0x0c),
            numRowOffsets: numRowOffsets,
            numRows: numRows,
            pageFlags: pageFlags,
            freeSize: try data.pioneerUInt16LE(at: pageOffset + 0x1c),
            usedSize: try data.pioneerUInt16LE(at: pageOffset + 0x1e),
            rows: rows
        )
    }

    /// Читает строки data-страницы через row index и row_present_flags.
    private static func readRows(
        _ data: Data,
        pageOffset: Int,
        pageSize: Int,
        tableType: PioneerDeviceSQLTableType,
        numRowOffsets: Int,
        pageFlags: UInt8
    ) throws -> [PioneerDeviceSQLReadbackRow] {
        guard pageFlags & 0x40 == 0 else { return [] }
        var rows: [PioneerDeviceSQLReadbackRow] = []
        let groupCount = PioneerDeviceSQLPage.rowGroupCount(for: numRowOffsets)
        for groupIndex in 0..<groupCount {
            let base = pageOffset + pageSize - (groupIndex * 0x24)
            let presentFlags = try data.pioneerUInt16LE(at: base - 4)
            for rowIndex in 0..<16 {
                let absoluteRowIndex = groupIndex * 16 + rowIndex
                guard absoluteRowIndex < numRowOffsets else { continue }
                guard ((presentFlags >> UInt16(rowIndex)) & 1) == 1 else { continue }
                let rowOffset = Int(try data.pioneerUInt16LE(at: base - (6 + (2 * rowIndex))))
                let rowBase = pageOffset + PioneerDeviceSQLPage.headerSize + rowOffset
                rows.append(try readRow(data, tableType: tableType, rowBase: rowBase))
            }
        }
        return rows
    }

    /// Читает строку конкретной таблицы.
    private static func readRow(
        _ data: Data,
        tableType: PioneerDeviceSQLTableType,
        rowBase: Int
    ) throws -> PioneerDeviceSQLReadbackRow {
        switch tableType {
        case .tracks:
            return try .track(readTrack(data, rowBase: rowBase))
        case .colors:
            return try .color(readColor(data, rowBase: rowBase))
        case .playlistTree:
            return try .playlistTree(readPlaylist(data, rowBase: rowBase))
        case .playlistEntries:
            return try .playlistEntry(readPlaylistEntry(data, rowBase: rowBase))
        case .genres,
             .artists,
             .albums,
             .labels,
             .keys,
             .unknown9,
             .unknown10,
             .unknown11,
             .unknown12,
             .artwork,
             .unknown14,
             .unknown15,
             .columns,
             .historyPlaylists,
             .historyEntries,
             .history:
            throw PioneerDeckExportError.invalidBinaryLayout("Строки \(tableType.tableName) пока не декодируются readback-инспектором.")
        }
    }

    /// Читает track_row.
    private static func readTrack(_ data: Data, rowBase: Int) throws -> PioneerDeviceSQLReadbackTrack {
        var offsets: [UInt16] = []
        for index in 0..<21 {
            offsets.append(try data.pioneerUInt16LE(at: rowBase + 94 + index * 2))
        }

        return PioneerDeviceSQLReadbackTrack(
            id: try data.pioneerUInt32LE(at: rowBase + 72),
            title: try readDeviceSQLString(data, at: rowBase + Int(offsets[17])),
            durationSeconds: try data.pioneerUInt16LE(at: rowBase + 84),
            sampleRate: try data.pioneerUInt32LE(at: rowBase + 8),
            fileSize: try data.pioneerUInt32LE(at: rowBase + 16),
            sampleDepth: try data.pioneerUInt16LE(at: rowBase + 82),
            bitrate: try data.pioneerUInt32LE(at: rowBase + 48),
            tempoX100: try data.pioneerUInt32LE(at: rowBase + 56),
            fileName: try readDeviceSQLString(data, at: rowBase + Int(offsets[19])),
            filePath: try readDeviceSQLString(data, at: rowBase + Int(offsets[20])),
            analyzePath: try readDeviceSQLString(data, at: rowBase + Int(offsets[14])),
            kuvoPublic: try readDeviceSQLString(data, at: rowBase + Int(offsets[6])),
            autoloadHotCues: try readDeviceSQLString(data, at: rowBase + Int(offsets[7])),
            analyzeDate: try readDeviceSQLString(data, at: rowBase + Int(offsets[15])),
            colorId: try data.pioneerUInt8(at: rowBase + 88)
        )
    }

    /// Читает playlist_tree_row.
    private static func readPlaylist(_ data: Data, rowBase: Int) throws -> PioneerDeviceSQLReadbackPlaylist {
        PioneerDeviceSQLReadbackPlaylist(
            parentId: try data.pioneerUInt32LE(at: rowBase),
            sortOrder: try data.pioneerUInt32LE(at: rowBase + 8),
            id: try data.pioneerUInt32LE(at: rowBase + 12),
            isFolder: try data.pioneerUInt32LE(at: rowBase + 16) != 0,
            name: try readDeviceSQLString(data, at: rowBase + 20)
        )
    }

    /// Читает playlist_entry_row.
    private static func readPlaylistEntry(_ data: Data, rowBase: Int) throws -> PioneerDeviceSQLReadbackPlaylistEntry {
        PioneerDeviceSQLReadbackPlaylistEntry(
            entryIndex: try data.pioneerUInt32LE(at: rowBase),
            trackId: try data.pioneerUInt32LE(at: rowBase + 4),
            playlistId: try data.pioneerUInt32LE(at: rowBase + 8)
        )
    }

    /// Читает color_row.
    private static func readColor(_ data: Data, rowBase: Int) throws -> PioneerDeviceSQLReadbackColor {
        PioneerDeviceSQLReadbackColor(
            id: try data.pioneerUInt16LE(at: rowBase + 5),
            name: try readDeviceSQLString(data, at: rowBase + 8)
        )
    }

    /// Читает device_sql_string.
    private static func readDeviceSQLString(_ data: Data, at offset: Int) throws -> String {
        let kind = try data.pioneerUInt8(at: offset)
        if kind & 1 == 1 {
            let length = Int(kind >> 1)
            let textCount = max(0, length - 1)
            let bytes = try data.pioneerReadData(in: (offset + 1)..<(offset + 1 + textCount))
            guard let text = String(data: bytes, encoding: .ascii) else {
                throw PioneerDeckExportError.invalidBinaryLayout("Short ASCII DeviceSQL-строка не декодируется.")
            }
            return text
        }

        let length = Int(try data.pioneerUInt16LE(at: offset + 1))
        let textCount = length - 4
        guard textCount >= 0 else {
            throw PioneerDeckExportError.invalidBinaryLayout("Long DeviceSQL-строка имеет некорректную длину.")
        }
        let bytes = try data.pioneerReadData(in: (offset + 4)..<(offset + 4 + textCount))

        switch kind {
        case 0x40:
            guard let text = String(data: bytes, encoding: .ascii) else {
                throw PioneerDeckExportError.invalidBinaryLayout("Long ASCII DeviceSQL-строка не декодируется.")
            }
            return text
        case 0x90:
            guard bytes.count % 2 == 0 else {
                throw PioneerDeckExportError.invalidBinaryLayout("UTF-16LE DeviceSQL-строка имеет нечётную длину.")
            }
            var units: [UInt16] = []
            for index in stride(from: 0, to: bytes.count, by: 2) {
                let low = UInt16(bytes[bytes.startIndex + index])
                let high = UInt16(bytes[bytes.startIndex + index + 1]) << 8
                units.append(low | high)
            }
            return String(decoding: units, as: UTF16.self)
        default:
            throw PioneerDeckExportError.invalidBinaryLayout("Неизвестный kind DeviceSQL-строки \(kind).")
        }
    }
}

private extension Data {
    /// Читает UInt8 по offset.
    func pioneerUInt8(at offset: Int) throws -> UInt8 {
        guard offset >= 0, offset < count else {
            throw PioneerDeckExportError.invalidBinaryLayout("UInt8 offset \(offset) за пределами файла.")
        }
        return self[offset]
    }

    /// Читает UInt16 little-endian по offset.
    func pioneerUInt16LE(at offset: Int) throws -> UInt16 {
        let bytes = try pioneerReadData(in: offset..<(offset + 2))
        return UInt16(bytes[bytes.startIndex]) | (UInt16(bytes[bytes.startIndex + 1]) << 8)
    }

    /// Читает UInt24 little-endian по offset.
    func pioneerUInt24LE(at offset: Int) throws -> UInt32 {
        let bytes = try pioneerReadData(in: offset..<(offset + 3))
        return UInt32(bytes[bytes.startIndex])
            | (UInt32(bytes[bytes.startIndex + 1]) << 8)
            | (UInt32(bytes[bytes.startIndex + 2]) << 16)
    }

    /// Читает UInt32 little-endian по offset.
    func pioneerUInt32LE(at offset: Int) throws -> UInt32 {
        let bytes = try pioneerReadData(in: offset..<(offset + 4))
        return UInt32(bytes[bytes.startIndex])
            | (UInt32(bytes[bytes.startIndex + 1]) << 8)
            | (UInt32(bytes[bytes.startIndex + 2]) << 16)
            | (UInt32(bytes[bytes.startIndex + 3]) << 24)
    }

    /// Читает диапазон байтов с проверкой границ.
    func pioneerReadData(in range: Range<Int>) throws -> Data {
        guard range.lowerBound >= 0, range.upperBound <= count else {
            throw PioneerDeckExportError.invalidBinaryLayout("Диапазон \(range) за пределами DeviceSQL файла.")
        }
        return subdata(in: range)
    }
}

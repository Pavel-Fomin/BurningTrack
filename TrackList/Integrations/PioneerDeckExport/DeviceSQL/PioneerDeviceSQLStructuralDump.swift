//
//  PioneerDeviceSQLStructuralDump.swift
//  TrackList
//
//  Dev-only структурный дамп legacy DeviceSQL export.pdb.
//

import Foundation

/// Структурный дамп DeviceSQL-файла без попытки полностью интерпретировать все таблицы rekordbox.
public struct PioneerDeviceSQLStructuralDump: Codable, Equatable, Sendable {
    /// Размер файла в байтах.
    public let fileSize: Int

    /// Количество страниц по len_page из header.
    public let filePageCount: Int

    /// Header первой страницы.
    public let header: PioneerDeviceSQLStructuralHeader

    /// Таблицы из table directory.
    public let tables: [PioneerDeviceSQLStructuralTable]

    /// Диагностические замечания, найденные во время чтения.
    public let issues: [PioneerDeviceSQLStructuralIssue]
}

/// Header первой страницы DeviceSQL.
public struct PioneerDeviceSQLStructuralHeader: Codable, Equatable, Sendable {
    /// Первое неизвестное поле header offset 0x00.
    public let unknownSignature: UInt32

    /// len_page из header.
    public let pageSize: UInt32

    /// num_tables из header.
    public let tableCount: UInt32

    /// next_unused_page из header.
    public let nextUnusedPage: UInt32

    /// Неизвестное поле header offset 0x10.
    public let unknown0x10: UInt32

    /// sequence из header.
    public let sequence: UInt32

    /// Gap offset 0x18...0x1b в hex.
    public let gapHex: String

    /// Первые байты header для ручного сравнения.
    public let rawHexPreview: String
}

/// Table pointer и прочитанная цепочка страниц.
public struct PioneerDeviceSQLStructuralTable: Codable, Equatable, Sendable {
    /// Индекс descriptor внутри table directory.
    public let descriptorIndex: Int

    /// Сырой page_type.
    public let type: UInt32

    /// Человекочитаемое имя table type.
    public let name: String

    /// empty_candidate из table pointer.
    public let emptyCandidate: UInt32

    /// first_page из table pointer.
    public let firstPage: UInt32

    /// last_page из table pointer.
    public let lastPage: UInt32

    /// Сырые 16 байт table pointer.
    public let descriptorHex: String

    /// Индексы страниц, пройденные по linked list.
    public let linkedPageIndexes: [UInt32]

    /// Страницы таблицы.
    public let pages: [PioneerDeviceSQLStructuralPage]

    /// Замечания по этой таблице.
    public let issues: [PioneerDeviceSQLStructuralIssue]
}

/// Одна страница DeviceSQL.
public struct PioneerDeviceSQLStructuralPage: Codable, Equatable, Sendable {
    /// Ожидаемый индекс страницы из linked list.
    public let pageIndex: UInt32

    /// Offset страницы в файле.
    public let fileOffset: Int

    /// page_index, записанный в header страницы.
    public let storedPageIndex: UInt32

    /// page_type страницы.
    public let tableType: UInt32

    /// Имя page_type.
    public let tableName: String

    /// next_page из header страницы.
    public let nextPage: UInt32

    /// sequence страницы.
    public let sequence: UInt32

    /// Неизвестное поле page header offset 0x14.
    public let unknown0x14: UInt32

    /// Упакованные row counts из offset 0x18...0x1a.
    public let packedRowCountsHex: String

    /// Количество выделенных row offsets.
    public let numRowOffsets: UInt16

    /// Количество валидных строк по header.
    public let numRows: UInt16

    /// page_flags.
    public let pageFlags: UInt8

    /// page_flags в hex.
    public let pageFlagsHex: String

    /// free_size из page header.
    public let freeSize: UInt16

    /// used_size из page header.
    public let usedSize: UInt16

    /// Количество row slots, покрываемое bitmap-группами.
    public let rowCapacity: Int

    /// Первые 40 байт page header.
    public let commonHeaderHex: String

    /// Data-page header, если page_flags указывает на data page.
    public let dataHeader: PioneerDeviceSQLStructuralDataPageHeader?

    /// Index-page header, если page_flags указывает на index page.
    public let indexHeader: PioneerDeviceSQLStructuralIndexPageHeader?

    /// Row groups из конца страницы.
    public let rowGroups: [PioneerDeviceSQLStructuralRowGroup]

    /// Присутствующие строки с оценкой размеров и декодированными id.
    public let presentRows: [PioneerDeviceSQLStructuralRowSlot]

    /// Замечания по странице.
    public let issues: [PioneerDeviceSQLStructuralIssue]
}

/// Поля data-page header после общей части page header.
public struct PioneerDeviceSQLStructuralDataPageHeader: Codable, Equatable, Sendable {
    /// transaction_row_count.
    public let transactionRowCount: UInt16

    /// transaction_row_index.
    public let transactionRowIndex: UInt16

    /// Неизвестное поле offset 0x24.
    public let unknown0x24: UInt16

    /// Неизвестное поле offset 0x26.
    public let unknown0x26: UInt16

    /// Raw preview data-page header.
    public let rawHexPreview: String
}

/// Поля index-page header.
public struct PioneerDeviceSQLStructuralIndexPageHeader: Codable, Equatable, Sendable {
    /// Неизвестное поле offset 0x20.
    public let unknown0x20: UInt16

    /// Неизвестное поле offset 0x22.
    public let unknown0x22: UInt16

    /// Magic offset 0x24.
    public let magic0x24: UInt16

    /// next_offset offset 0x26.
    public let nextOffset: UInt16

    /// Зеркальный page_index offset 0x28.
    public let mirroredPageIndex: UInt32

    /// Зеркальный next_page offset 0x2c.
    public let mirroredNextPage: UInt32

    /// Magic offset 0x30.
    public let magic0x30: UInt32

    /// Нулевое поле offset 0x34.
    public let zero0x34: UInt32

    /// num_entries offset 0x38.
    public let numEntries: UInt16

    /// first_empty offset 0x3a.
    public let firstEmpty: UInt16

    /// Raw preview index-page header.
    public let rawHexPreview: String
}

/// Одна группа row index.
public struct PioneerDeviceSQLStructuralRowGroup: Codable, Equatable, Sendable {
    /// Индекс группы row index.
    public let groupIndex: Int

    /// Offset начала группы относительно страницы.
    public let baseOffsetInPage: Int

    /// Bitmap присутствующих строк.
    public let rowPresenceBitmap: UInt16

    /// Bitmap строк последней транзакции.
    public let transactionBitmap: UInt16

    /// Количество выставленных битов присутствия.
    public let presentRowCount: Int

    /// Все slots группы.
    public let rowSlots: [PioneerDeviceSQLStructuralRowSlot]
}

/// Slot row index.
public struct PioneerDeviceSQLStructuralRowSlot: Codable, Equatable, Sendable {
    /// Абсолютный индекс строки внутри страницы.
    public let rowIndex: Int

    /// Индекс строки внутри группы.
    public let rowIndexInGroup: Int

    /// Выделен ли slot по num_row_offsets.
    public let isAllocated: Bool

    /// Присутствует ли строка по bitmap.
    public let isPresent: Bool

    /// Offset строки относительно начала heap.
    public let rowOffset: UInt16?

    /// Offset строки внутри файла.
    public let rowBaseFileOffset: Int?

    /// Оценка размера строки по соседним offsets и used_size.
    public let estimatedRowSize: Int?

    /// Raw preview строки.
    public let rawHexPreview: String?

    /// Декодированные id-поля для известных таблиц.
    public let decoded: PioneerDeviceSQLStructuralDecodedRow?
}

/// Минимально декодированные поля row.
public struct PioneerDeviceSQLStructuralDecodedRow: Codable, Equatable, Sendable {
    /// Тип строки.
    public let kind: String

    /// Основной id строки, если он подтверждён.
    public let id: UInt32?

    /// Дополнительные id/позиционные поля.
    public let fields: [String: String]
}

/// Диагностическое замечание structural dump/diff.
public struct PioneerDeviceSQLStructuralIssue: Codable, Equatable, Sendable {
    /// Уровень серьёзности.
    public let severity: PioneerDeviceSQLStructuralSeverity

    /// Категория.
    public let category: String

    /// Путь внутри дампа.
    public let path: String

    /// Сообщение.
    public let message: String

    /// Создаёт диагностическое замечание.
    public init(
        severity: PioneerDeviceSQLStructuralSeverity,
        category: String,
        path: String,
        message: String
    ) {
        self.severity = severity
        self.category = category
        self.path = path
        self.message = message
    }
}

/// Уровень серьёзности structural diff.
public enum PioneerDeviceSQLStructuralSeverity: String, Codable, Equatable, Sendable {
    /// Ошибка, которая может ломать чтение rekordbox.
    case critical

    /// Подозрительное отличие или неполная совместимость.
    case warning

    /// Информационное отличие.
    case info
}

/// Tolerant-инспектор DeviceSQL для сравнения настоящего rekordbox export.pdb и generated export.pdb.
public enum PioneerDeviceSQLStructuralDumpBuilder {
    /// Длина фиксированной части track_row до массива offset-ов строк.
    private static let trackFixedLength = 136

    /// Fixed-поля track_row: имя, offset и размер по rekordbox_pdb.ksy.
    private static let trackFixedFieldDescriptors: [(name: String, offset: Int, length: Int)] = [
        ("subtype", 0x00, 2),
        ("index_shift", 0x02, 2),
        ("bitmask", 0x04, 4),
        ("sample_rate", 0x08, 4),
        ("composer_id", 0x0c, 4),
        ("file_size", 0x10, 4),
        ("unknown_id", 0x14, 4),
        ("unknown_0x18", 0x18, 2),
        ("unknown_0x1a", 0x1a, 2),
        ("artwork_id", 0x1c, 4),
        ("key_id", 0x20, 4),
        ("original_artist_id", 0x24, 4),
        ("label_id", 0x28, 4),
        ("remixer_id", 0x2c, 4),
        ("bitrate", 0x30, 4),
        ("track_number", 0x34, 4),
        ("tempo_x100", 0x38, 4),
        ("genre_id", 0x3c, 4),
        ("album_id", 0x40, 4),
        ("artist_id", 0x44, 4),
        ("track_id", 0x48, 4),
        ("disc_number", 0x4c, 2),
        ("play_count", 0x4e, 2),
        ("year", 0x50, 2),
        ("sample_depth", 0x52, 2),
        ("duration", 0x54, 2),
        ("unknown_0x56", 0x56, 2),
        ("color_id", 0x58, 1),
        ("rating", 0x59, 1),
        ("unknown_0x5a", 0x5a, 2),
        ("unknown_0x5c", 0x5c, 2)
    ]

    /// Имена строковых полей track_row в порядке ofs_strings из rekordbox_pdb.ksy.
    private static let trackStringFieldNames = [
        "isrc",
        "texter",
        "unknown_string_2",
        "unknown_string_3",
        "unknown_string_4",
        "message",
        "kuvo_public",
        "autoload_hot_cues",
        "unknown_string_5",
        "unknown_string_6",
        "date_added",
        "release_date",
        "mix_name",
        "unknown_string_7",
        "analyze_path",
        "analyze_date",
        "comment",
        "title",
        "unknown_string_8",
        "filename",
        "file_path"
    ]

    /// Строит структурный дамп export.pdb.
    public static func inspect(data: Data) throws -> PioneerDeviceSQLStructuralDump {
        guard data.count >= PioneerDeviceSQLHeader.tableDirectoryOffset else {
            throw PioneerDeckExportError.invalidBinaryLayout("DeviceSQL header короче 0x1c.")
        }

        let header = try makeHeader(data)
        let pageSize = Int(header.pageSize)
        guard pageSize > 0 else {
            throw PioneerDeckExportError.invalidBinaryLayout("DeviceSQL len_page равен 0.")
        }

        let filePageCount = data.count / pageSize
        var issues: [PioneerDeviceSQLStructuralIssue] = []
        if data.count % pageSize != 0 {
            issues.append(
                issue(
                    .critical,
                    "file_size",
                    "$.fileSize",
                    "Размер файла не кратен len_page."
                )
            )
        }
        if header.nextUnusedPage != UInt32(filePageCount) {
            issues.append(
                issue(
                    .critical,
                    "header",
                    "$.header.nextUnusedPage",
                    "next_unused_page не совпадает с количеством страниц файла."
                )
            )
        }
        if header.gapHex != "00000000" {
            issues.append(
                issue(
                    .critical,
                    "header",
                    "$.header.gapHex",
                    "Header gap offset 0x18...0x1b не равен нулю."
                )
            )
        }

        let descriptors = try makeTableDescriptors(data, header: header)
        let tables = descriptors.map { descriptor in
            makeTable(data, descriptor: descriptor, pageSize: pageSize)
        }
        issues.append(contentsOf: tables.flatMap(\.issues))

        return PioneerDeviceSQLStructuralDump(
            fileSize: data.count,
            filePageCount: filePageCount,
            header: header,
            tables: tables,
            issues: issues
        )
    }

    /// Возвращает имя table type из rekordbox_pdb.ksy.
    public static func tableName(for type: UInt32) -> String {
        switch type {
        case 0:
            return "tracks"
        case 1:
            return "genres"
        case 2:
            return "artists"
        case 3:
            return "albums"
        case 4:
            return "labels"
        case 5:
            return "keys"
        case 6:
            return "colors"
        case 7:
            return "playlist_tree"
        case 8:
            return "playlist_entries"
        case 13:
            return "artwork"
        case 16:
            return "columns"
        case 17:
            return "history_playlists"
        case 18:
            return "history_entries"
        case 19:
            return "history"
        default:
            return String(format: "unknown_0x%02x", type)
        }
    }

    /// Читает header первой страницы.
    private static func makeHeader(_ data: Data) throws -> PioneerDeviceSQLStructuralHeader {
        PioneerDeviceSQLStructuralHeader(
            unknownSignature: try data.structuralUInt32LE(at: 0x00),
            pageSize: try data.structuralUInt32LE(at: 0x04),
            tableCount: try data.structuralUInt32LE(at: 0x08),
            nextUnusedPage: try data.structuralUInt32LE(at: 0x0c),
            unknown0x10: try data.structuralUInt32LE(at: 0x10),
            sequence: try data.structuralUInt32LE(at: 0x14),
            gapHex: try data.structuralHex(in: 0x18..<0x1c),
            rawHexPreview: try data.structuralHex(in: 0..<min(data.count, 0x40))
        )
    }

    /// Читает table directory без ограничения на известные table types.
    private static func makeTableDescriptors(
        _ data: Data,
        header: PioneerDeviceSQLStructuralHeader
    ) throws -> [PioneerDeviceSQLStructuralTableDescriptor] {
        let descriptorCount = Int(header.tableCount)
        return try (0..<descriptorCount).map { index in
            let offset = PioneerDeviceSQLHeader.tableDirectoryOffset + index * PioneerDeviceSQLHeader.tableDescriptorSize
            return PioneerDeviceSQLStructuralTableDescriptor(
                descriptorIndex: index,
                type: try data.structuralUInt32LE(at: offset),
                emptyCandidate: try data.structuralUInt32LE(at: offset + 0x04),
                firstPage: try data.structuralUInt32LE(at: offset + 0x08),
                lastPage: try data.structuralUInt32LE(at: offset + 0x0c),
                descriptorHex: try data.structuralHex(in: offset..<(offset + PioneerDeviceSQLHeader.tableDescriptorSize))
            )
        }
    }

    /// Читает таблицу по linked list страниц.
    private static func makeTable(
        _ data: Data,
        descriptor: PioneerDeviceSQLStructuralTableDescriptor,
        pageSize: Int
    ) -> PioneerDeviceSQLStructuralTable {
        var pages: [PioneerDeviceSQLStructuralPage] = []
        var linkedPageIndexes: [UInt32] = []
        var tableIssues: [PioneerDeviceSQLStructuralIssue] = []
        var visited = Set<UInt32>()
        var currentPageIndex = descriptor.firstPage
        let terminalPageIndex = UInt32(data.count / pageSize)

        while true {
            let path = "$.tables[\(descriptor.descriptorIndex)].pages[\(linkedPageIndexes.count)]"
            guard visited.insert(currentPageIndex).inserted else {
                tableIssues.append(issue(.critical, "page_chain", path, "Цепочка страниц зациклена на page \(currentPageIndex)."))
                break
            }

            linkedPageIndexes.append(currentPageIndex)
            guard let page = makePage(
                data,
                descriptor: descriptor,
                pageIndex: currentPageIndex,
                pageSize: pageSize,
                path: path
            ) else {
                tableIssues.append(issue(.critical, "page_chain", path, "Страница \(currentPageIndex) находится за пределами файла."))
                break
            }
            pages.append(page)
            tableIssues.append(contentsOf: page.issues)

            if currentPageIndex == descriptor.lastPage {
                break
            }
            if page.nextPage >= terminalPageIndex && page.nextPage != descriptor.lastPage {
                tableIssues.append(
                    issue(
                        .critical,
                        "page_chain",
                        path + ".nextPage",
                        "next_page \(page.nextPage) указывает за пределы файла до достижения last_page \(descriptor.lastPage)."
                    )
                )
                break
            }
            currentPageIndex = page.nextPage
        }

        return PioneerDeviceSQLStructuralTable(
            descriptorIndex: descriptor.descriptorIndex,
            type: descriptor.type,
            name: tableName(for: descriptor.type),
            emptyCandidate: descriptor.emptyCandidate,
            firstPage: descriptor.firstPage,
            lastPage: descriptor.lastPage,
            descriptorHex: descriptor.descriptorHex,
            linkedPageIndexes: linkedPageIndexes,
            pages: pages,
            issues: tableIssues
        )
    }

    /// Читает одну страницу таблицы.
    private static func makePage(
        _ data: Data,
        descriptor: PioneerDeviceSQLStructuralTableDescriptor,
        pageIndex: UInt32,
        pageSize: Int,
        path: String
    ) -> PioneerDeviceSQLStructuralPage? {
        let pageOffset = Int(pageIndex) * pageSize
        guard pageOffset >= 0, pageOffset + pageSize <= data.count else { return nil }

        var issues: [PioneerDeviceSQLStructuralIssue] = []
        let storedPageIndex = (try? data.structuralUInt32LE(at: pageOffset + 0x04)) ?? 0
        let tableType = (try? data.structuralUInt32LE(at: pageOffset + 0x08)) ?? UInt32.max
        let pageFlags = (try? data.structuralUInt8(at: pageOffset + 0x1b)) ?? 0
        let packedRows = (try? data.structuralUInt24LE(at: pageOffset + 0x18)) ?? 0
        let numRowOffsets = UInt16(packedRows & 0x1fff)
        let numRows = UInt16((packedRows >> 13) & 0x07ff)
        let hasDataRows = pageFlags & 0x40 == 0 && numRowOffsets > 0
        let rowCapacity = PioneerDeviceSQLPage.rowGroupCount(for: Int(numRowOffsets)) * 16

        if storedPageIndex != pageIndex {
            issues.append(issue(.critical, "page_header", path + ".storedPageIndex", "page_index в header не совпадает с linked page index."))
        }
        if tableType != descriptor.type {
            issues.append(issue(.critical, "page_header", path + ".tableType", "page_type не совпадает с table descriptor."))
        }
        if ![0x24, 0x34, 0x44, 0x64].contains(pageFlags) {
            issues.append(issue(.critical, "page_header", path + ".pageFlags", "page_flags имеет неизвестное значение."))
        }

        let rowGroups = makeRowGroups(
            data,
            pageOffset: pageOffset,
            pageSize: pageSize,
            tableType: tableType,
            numRowOffsets: Int(numRowOffsets),
            usedSize: Int((try? data.structuralUInt16LE(at: pageOffset + 0x1e)) ?? 0),
            hasDataRows: hasDataRows,
            path: path,
            issues: &issues
        )
        let presentRows = rowGroups.flatMap(\.rowSlots).filter(\.isPresent)
        if presentRows.count != Int(numRows) {
            issues.append(
                issue(
                    .critical,
                    "row_index",
                    path + ".numRows",
                    "num_rows \(numRows) не совпадает с количеством present bits \(presentRows.count)."
                )
            )
        }

        return PioneerDeviceSQLStructuralPage(
            pageIndex: pageIndex,
            fileOffset: pageOffset,
            storedPageIndex: storedPageIndex,
            tableType: tableType,
            tableName: tableName(for: tableType),
            nextPage: (try? data.structuralUInt32LE(at: pageOffset + 0x0c)) ?? 0,
            sequence: (try? data.structuralUInt32LE(at: pageOffset + 0x10)) ?? 0,
            unknown0x14: (try? data.structuralUInt32LE(at: pageOffset + 0x14)) ?? 0,
            packedRowCountsHex: (try? data.structuralHex(in: (pageOffset + 0x18)..<(pageOffset + 0x1b))) ?? "",
            numRowOffsets: numRowOffsets,
            numRows: numRows,
            pageFlags: pageFlags,
            pageFlagsHex: String(format: "0x%02x", pageFlags),
            freeSize: (try? data.structuralUInt16LE(at: pageOffset + 0x1c)) ?? 0,
            usedSize: (try? data.structuralUInt16LE(at: pageOffset + 0x1e)) ?? 0,
            rowCapacity: rowCapacity,
            commonHeaderHex: (try? data.structuralHex(in: pageOffset..<(pageOffset + min(pageSize, PioneerDeviceSQLPage.headerSize)))) ?? "",
            dataHeader: pageFlags & 0x40 == 0 ? makeDataHeader(data, pageOffset: pageOffset) : nil,
            indexHeader: pageFlags & 0x40 != 0 ? makeIndexHeader(data, pageOffset: pageOffset) : nil,
            rowGroups: rowGroups,
            presentRows: presentRows,
            issues: issues
        )
    }

    /// Читает data-page header.
    private static func makeDataHeader(_ data: Data, pageOffset: Int) -> PioneerDeviceSQLStructuralDataPageHeader {
        PioneerDeviceSQLStructuralDataPageHeader(
            transactionRowCount: (try? data.structuralUInt16LE(at: pageOffset + 0x20)) ?? 0,
            transactionRowIndex: (try? data.structuralUInt16LE(at: pageOffset + 0x22)) ?? 0,
            unknown0x24: (try? data.structuralUInt16LE(at: pageOffset + 0x24)) ?? 0,
            unknown0x26: (try? data.structuralUInt16LE(at: pageOffset + 0x26)) ?? 0,
            rawHexPreview: (try? data.structuralHex(in: (pageOffset + 0x20)..<(pageOffset + 0x28))) ?? ""
        )
    }

    /// Читает index-page header.
    private static func makeIndexHeader(_ data: Data, pageOffset: Int) -> PioneerDeviceSQLStructuralIndexPageHeader {
        PioneerDeviceSQLStructuralIndexPageHeader(
            unknown0x20: (try? data.structuralUInt16LE(at: pageOffset + 0x20)) ?? 0,
            unknown0x22: (try? data.structuralUInt16LE(at: pageOffset + 0x22)) ?? 0,
            magic0x24: (try? data.structuralUInt16LE(at: pageOffset + 0x24)) ?? 0,
            nextOffset: (try? data.structuralUInt16LE(at: pageOffset + 0x26)) ?? 0,
            mirroredPageIndex: (try? data.structuralUInt32LE(at: pageOffset + 0x28)) ?? 0,
            mirroredNextPage: (try? data.structuralUInt32LE(at: pageOffset + 0x2c)) ?? 0,
            magic0x30: (try? data.structuralUInt32LE(at: pageOffset + 0x30)) ?? 0,
            zero0x34: (try? data.structuralUInt32LE(at: pageOffset + 0x34)) ?? 0,
            numEntries: (try? data.structuralUInt16LE(at: pageOffset + 0x38)) ?? 0,
            firstEmpty: (try? data.structuralUInt16LE(at: pageOffset + 0x3a)) ?? 0,
            rawHexPreview: (try? data.structuralHex(in: (pageOffset + 0x20)..<(pageOffset + 0x40))) ?? ""
        )
    }

    /// Читает row index и минимальные previews строк.
    private static func makeRowGroups(
        _ data: Data,
        pageOffset: Int,
        pageSize: Int,
        tableType: UInt32,
        numRowOffsets: Int,
        usedSize: Int,
        hasDataRows: Bool,
        path: String,
        issues: inout [PioneerDeviceSQLStructuralIssue]
    ) -> [PioneerDeviceSQLStructuralRowGroup] {
        guard hasDataRows else { return [] }

        let groupCount = PioneerDeviceSQLPage.rowGroupCount(for: numRowOffsets)
        let presentOffsets = collectPresentOffsets(data, pageOffset: pageOffset, pageSize: pageSize, numRowOffsets: numRowOffsets)
        var groups: [PioneerDeviceSQLStructuralRowGroup] = []

        for groupIndex in 0..<groupCount {
            let base = pageOffset + pageSize - (groupIndex * 0x24)
            let presentFlags = (try? data.structuralUInt16LE(at: base - 4)) ?? 0
            let transactionFlags = (try? data.structuralUInt16LE(at: base - 2)) ?? 0
            var slots: [PioneerDeviceSQLStructuralRowSlot] = []

            for rowIndexInGroup in 0..<16 {
                let absoluteRowIndex = groupIndex * 16 + rowIndexInGroup
                let isAllocated = absoluteRowIndex < numRowOffsets
                let isPresent = isAllocated && ((presentFlags >> UInt16(rowIndexInGroup)) & 1) == 1
                let rowOffset = isAllocated ? (try? data.structuralUInt16LE(at: base - (6 + 2 * rowIndexInGroup))) : nil
                let rowBase = rowOffset.map { pageOffset + PioneerDeviceSQLPage.headerSize + Int($0) }
                let rowSize = rowOffset.flatMap {
                    estimateRowSize(rowOffset: Int($0), presentOffsets: presentOffsets, usedSize: usedSize)
                }

                if isPresent {
                    if let rowOffset, Int(rowOffset) >= usedSize {
                        issues.append(
                            issue(
                                .critical,
                                "row_index",
                                path + ".rowGroups[\(groupIndex)].rowSlots[\(rowIndexInGroup)]",
                                "row offset \(rowOffset) выходит за used_size \(usedSize)."
                            )
                        )
                    }
                    if let rowBase, rowBase >= pageOffset + pageSize {
                        issues.append(
                            issue(
                                .critical,
                                "row_index",
                                path + ".rowGroups[\(groupIndex)].rowSlots[\(rowIndexInGroup)]",
                                "row base выходит за пределы страницы."
                            )
                        )
                    }
                }

                let decoded = isPresent
                    ? annotateDecodedRow(
                        decodeKnownRow(data, tableType: tableType, rowBase: rowBase, rowSize: rowSize),
                        rowIndex: absoluteRowIndex,
                        rowIndexInGroup: rowIndexInGroup,
                        rowOffset: rowOffset,
                        rowBaseFileOffset: rowBase,
                        estimatedRowSize: rowSize
                    )
                    : nil

                slots.append(
                    PioneerDeviceSQLStructuralRowSlot(
                        rowIndex: absoluteRowIndex,
                        rowIndexInGroup: rowIndexInGroup,
                        isAllocated: isAllocated,
                        isPresent: isPresent,
                        rowOffset: rowOffset,
                        rowBaseFileOffset: isPresent ? rowBase : nil,
                        estimatedRowSize: isPresent ? rowSize : nil,
                        rawHexPreview: isPresent ? rawRowPreview(data, rowBase: rowBase, rowSize: rowSize) : nil,
                        decoded: decoded
                    )
                )
            }

            groups.append(
                PioneerDeviceSQLStructuralRowGroup(
                    groupIndex: groupIndex,
                    baseOffsetInPage: pageSize - (groupIndex * 0x24),
                    rowPresenceBitmap: presentFlags,
                    transactionBitmap: transactionFlags,
                    presentRowCount: Int(presentFlags.nonzeroBitCount),
                    rowSlots: slots
                )
            )
        }

        return groups
    }

    /// Собирает offsets строк, отмеченных present bits.
    private static func collectPresentOffsets(
        _ data: Data,
        pageOffset: Int,
        pageSize: Int,
        numRowOffsets: Int
    ) -> [Int] {
        var offsets: [Int] = []
        let groupCount = PioneerDeviceSQLPage.rowGroupCount(for: numRowOffsets)
        for groupIndex in 0..<groupCount {
            let base = pageOffset + pageSize - (groupIndex * 0x24)
            let presentFlags = (try? data.structuralUInt16LE(at: base - 4)) ?? 0
            for rowIndex in 0..<16 {
                let absoluteRowIndex = groupIndex * 16 + rowIndex
                guard absoluteRowIndex < numRowOffsets else { continue }
                guard ((presentFlags >> UInt16(rowIndex)) & 1) == 1 else { continue }
                if let rowOffset = try? data.structuralUInt16LE(at: base - (6 + 2 * rowIndex)) {
                    offsets.append(Int(rowOffset))
                }
            }
        }
        return offsets.sorted()
    }

    /// Оценивает размер строки по следующему offset или used_size.
    private static func estimateRowSize(rowOffset: Int, presentOffsets: [Int], usedSize: Int) -> Int? {
        let sortedOffsets = presentOffsets.sorted()
        guard let index = sortedOffsets.firstIndex(of: rowOffset) else { return nil }
        let end = index + 1 < sortedOffsets.count ? sortedOffsets[index + 1] : usedSize
        guard end >= rowOffset else { return nil }
        return end - rowOffset
    }

    /// Добавляет диагностические координаты строки к decoded fields.
    private static func annotateDecodedRow(
        _ decoded: PioneerDeviceSQLStructuralDecodedRow?,
        rowIndex: Int,
        rowIndexInGroup: Int,
        rowOffset: UInt16?,
        rowBaseFileOffset: Int?,
        estimatedRowSize: Int?
    ) -> PioneerDeviceSQLStructuralDecodedRow? {
        guard let decoded else { return nil }
        var fields = decoded.fields
        fields["row_index"] = "\(rowIndex)"
        fields["row_index_in_group"] = "\(rowIndexInGroup)"
        fields["row_offset"] = rowOffset.map { String(format: "0x%04x", $0) } ?? ""
        fields["row_base_file_offset"] = rowBaseFileOffset.map(String.init) ?? ""
        fields["estimated_row_size"] = estimatedRowSize.map(String.init) ?? ""
        return PioneerDeviceSQLStructuralDecodedRow(kind: decoded.kind, id: decoded.id, fields: fields)
    }

    /// Возвращает raw preview строки.
    private static func rawRowPreview(_ data: Data, rowBase: Int?, rowSize: Int?) -> String? {
        guard let rowBase, let rowSize, rowSize > 0 else { return nil }
        let end = min(data.count, rowBase + min(rowSize, 32))
        guard rowBase >= 0, rowBase < end else { return nil }
        return try? data.structuralHex(in: rowBase..<end)
    }

    /// Декодирует id-поля для таблиц, структура которых уже используется writer-слоем.
    private static func decodeKnownRow(
        _ data: Data,
        tableType: UInt32,
        rowBase: Int?,
        rowSize: Int?
    ) -> PioneerDeviceSQLStructuralDecodedRow? {
        guard let rowBase else { return nil }
        switch tableType {
        case 0:
            return decodeTrackRow(data, rowBase: rowBase, rowSize: rowSize)
        case 6:
            guard
                let id = try? data.structuralUInt16LE(at: rowBase + 5),
                let name = try? readStructuralDeviceSQLString(data, at: rowBase + 8)
            else { return nil }
            let paddingSize = max(0, (rowSize ?? 0) - 8 - name.encodedSize)
            let paddingStart = rowBase + 8 + name.encodedSize
            let paddingHex: String
            if paddingSize > 0 {
                paddingHex = (try? data.structuralHex(in: paddingStart..<(paddingStart + paddingSize))) ?? ""
            } else {
                paddingHex = ""
            }
            var fields = [
                "unknown_0x00_hex": ((try? data.structuralHex(in: rowBase..<(rowBase + 4))) ?? ""),
                "unknown_0x04": "\((try? data.structuralUInt8(at: rowBase + 4)) ?? 0)",
                "color_id": "\(id)",
                "unknown_0x07": "\((try? data.structuralUInt8(at: rowBase + 7)) ?? 0)",
                "name": name.text,
                "string_kind": name.kindHex,
                "string_encoded_size": "\(name.encodedSize)",
                "padding_size": "\(paddingSize)",
                "padding_hex": paddingHex
            ]
            if let rowSize {
                fields["row_size"] = "\(rowSize)"
            }
            return PioneerDeviceSQLStructuralDecodedRow(kind: "color", id: UInt32(id), fields: fields)
        case 7:
            guard
                let parentId = try? data.structuralUInt32LE(at: rowBase),
                let sortOrder = try? data.structuralUInt32LE(at: rowBase + 8),
                let id = try? data.structuralUInt32LE(at: rowBase + 12),
                let rawIsFolder = try? data.structuralUInt32LE(at: rowBase + 16),
                let name = try? readStructuralDeviceSQLString(data, at: rowBase + 20)
            else { return nil }
            let paddingSize = max(0, (rowSize ?? 0) - 20 - name.encodedSize)
            let paddingStart = rowBase + 20 + name.encodedSize
            let paddingHex: String
            if paddingSize > 0 {
                paddingHex = (try? data.structuralHex(in: paddingStart..<(paddingStart + paddingSize))) ?? ""
            } else {
                paddingHex = ""
            }
            var fields = [
                "parent_id": "\(parentId)",
                "unknown_0x04_hex": ((try? data.structuralHex(in: (rowBase + 4)..<(rowBase + 8))) ?? ""),
                "sort_order": "\(sortOrder)",
                "raw_is_folder": "\(rawIsFolder)",
                "is_folder": "\(rawIsFolder != 0)",
                "name": name.text,
                "string_kind": name.kindHex,
                "string_encoded_size": "\(name.encodedSize)",
                "padding_size": "\(paddingSize)",
                "padding_hex": paddingHex
            ]
            if let rowSize {
                fields["row_size"] = "\(rowSize)"
            }
            return PioneerDeviceSQLStructuralDecodedRow(
                kind: "playlist_tree",
                id: id,
                fields: fields
            )
        case 8:
            guard
                let entryIndex = try? data.structuralUInt32LE(at: rowBase),
                let trackId = try? data.structuralUInt32LE(at: rowBase + 4),
                let playlistId = try? data.structuralUInt32LE(at: rowBase + 8)
            else { return nil }
            return PioneerDeviceSQLStructuralDecodedRow(
                kind: "playlist_entry",
                id: entryIndex,
                fields: [
                    "entry_index": "\(entryIndex)",
                    "track_id": "\(trackId)",
                    "playlist_id": "\(playlistId)"
                ]
            )
        default:
            return nil
        }
    }

    /// Декодирует track_row по подтверждённой части rekordbox_pdb.ksy.
    private static func decodeTrackRow(
        _ data: Data,
        rowBase: Int,
        rowSize: Int?
    ) -> PioneerDeviceSQLStructuralDecodedRow? {
        guard
            let subtype = try? data.structuralUInt16LE(at: rowBase),
            let indexShift = try? data.structuralUInt16LE(at: rowBase + 0x02),
            let bitmask = try? data.structuralUInt32LE(at: rowBase + 0x04),
            let sampleRate = try? data.structuralUInt32LE(at: rowBase + 0x08),
            let composerId = try? data.structuralUInt32LE(at: rowBase + 0x0c),
            let fileSize = try? data.structuralUInt32LE(at: rowBase + 0x10),
            let unknownId = try? data.structuralUInt32LE(at: rowBase + 0x14),
            let unknown0x18 = try? data.structuralUInt16LE(at: rowBase + 0x18),
            let unknown0x1a = try? data.structuralUInt16LE(at: rowBase + 0x1a),
            let artworkId = try? data.structuralUInt32LE(at: rowBase + 0x1c),
            let keyId = try? data.structuralUInt32LE(at: rowBase + 0x20),
            let originalArtistId = try? data.structuralUInt32LE(at: rowBase + 0x24),
            let labelId = try? data.structuralUInt32LE(at: rowBase + 0x28),
            let remixerId = try? data.structuralUInt32LE(at: rowBase + 0x2c),
            let bitrate = try? data.structuralUInt32LE(at: rowBase + 0x30),
            let trackNumber = try? data.structuralUInt32LE(at: rowBase + 0x34),
            let tempo = try? data.structuralUInt32LE(at: rowBase + 0x38),
            let genreId = try? data.structuralUInt32LE(at: rowBase + 0x3c),
            let albumId = try? data.structuralUInt32LE(at: rowBase + 0x40),
            let artistId = try? data.structuralUInt32LE(at: rowBase + 0x44),
            let id = try? data.structuralUInt32LE(at: rowBase + 0x48),
            let discNumber = try? data.structuralUInt16LE(at: rowBase + 0x4c),
            let playCount = try? data.structuralUInt16LE(at: rowBase + 0x4e),
            let year = try? data.structuralUInt16LE(at: rowBase + 0x50),
            let sampleDepth = try? data.structuralUInt16LE(at: rowBase + 0x52),
            let duration = try? data.structuralUInt16LE(at: rowBase + 0x54),
            let unknown0x56 = try? data.structuralUInt16LE(at: rowBase + 0x56),
            let colorId = try? data.structuralUInt8(at: rowBase + 0x58),
            let rating = try? data.structuralUInt8(at: rowBase + 0x59),
            let unknown0x5a = try? data.structuralUInt16LE(at: rowBase + 0x5a),
            let unknown0x5c = try? data.structuralUInt16LE(at: rowBase + 0x5c)
        else {
            return nil
        }

        var fields = [
            "subtype": String(format: "0x%04x", subtype),
            "index_shift": "\(indexShift)",
            "bitmask": "\(bitmask)",
            "bitmask_hex": String(format: "0x%08x", bitmask),
            "sample_rate": "\(sampleRate)",
            "composer_id": "\(composerId)",
            "file_size": "\(fileSize)",
            "unknown_id": "\(unknownId)",
            "unknown_0x14_hex": ((try? data.structuralHex(in: (rowBase + 0x14)..<(rowBase + 0x18))) ?? ""),
            "unknown_0x18": "\(unknown0x18)",
            "unknown_0x18_hex": ((try? data.structuralHex(in: (rowBase + 0x18)..<(rowBase + 0x1a))) ?? ""),
            "unknown_0x1a": "\(unknown0x1a)",
            "unknown_0x1a_hex": ((try? data.structuralHex(in: (rowBase + 0x1a)..<(rowBase + 0x1c))) ?? ""),
            "artwork_id": "\(artworkId)",
            "key_id": "\(keyId)",
            "original_artist_id": "\(originalArtistId)",
            "label_id": "\(labelId)",
            "remixer_id": "\(remixerId)",
            "bitrate": "\(bitrate)",
            "track_number": "\(trackNumber)",
            "tempo_x100": "\(tempo)",
            "bpm": String(format: "%.2f", Double(tempo) / 100.0),
            "genre_id": "\(genreId)",
            "album_id": "\(albumId)",
            "artist_id": "\(artistId)",
            "track_id": "\(id)",
            "disc_number": "\(discNumber)",
            "play_count": "\(playCount)",
            "year": "\(year)",
            "sample_depth": "\(sampleDepth)",
            "duration": "\(duration)",
            "unknown_0x56": "\(unknown0x56)",
            "unknown_0x56_hex": ((try? data.structuralHex(in: (rowBase + 0x56)..<(rowBase + 0x58))) ?? ""),
            "color_id": "\(colorId)",
            "rating": "\(rating)",
            "unknown_0x5a": "\(unknown0x5a)",
            "unknown_0x5a_hex": ((try? data.structuralHex(in: (rowBase + 0x5a)..<(rowBase + 0x5c))) ?? ""),
            "unknown_0x5c": "\(unknown0x5c)",
            "unknown_0x5c_hex": ((try? data.structuralHex(in: (rowBase + 0x5c)..<(rowBase + 0x5e))) ?? ""),
            "fixed_fields_hex": ((try? data.structuralHex(in: rowBase..<(rowBase + min(trackFixedLength, rowSize ?? trackFixedLength)))) ?? "")
        ]

        if let rowSize {
            fields["row_size"] = "\(rowSize)"
        }
        addTrackFixedFieldDiagnostics(data, rowBase: rowBase, fields: &fields)

        let offsets = readTrackStringOffsets(data, rowBase: rowBase)
        fields["ofs_strings_hex"] = offsets
            .map { String(format: "%04x", $0) }
            .joined(separator: ",")

        for (index, fieldName) in trackStringFieldNames.enumerated() {
            guard index < offsets.count else { continue }
            decodeTrackStringField(
                fieldName,
                offset: Int(offsets[index]),
                offsets: offsets.map(Int.init),
                data: data,
                rowBase: rowBase,
                rowSize: rowSize,
                fields: &fields
            )
        }

        return PioneerDeviceSQLStructuralDecodedRow(kind: "track", id: id, fields: fields)
    }

    /// Добавляет offset/raw hex для fixed-полей track_row.
    private static func addTrackFixedFieldDiagnostics(
        _ data: Data,
        rowBase: Int,
        fields: inout [String: String]
    ) {
        for descriptor in trackFixedFieldDescriptors {
            fields["\(descriptor.name)_offset"] = String(format: "0x%02x", descriptor.offset)
            fields["\(descriptor.name)_raw_hex"] = (
                try? data.structuralHex(in: (rowBase + descriptor.offset)..<(rowBase + descriptor.offset + descriptor.length))
            ) ?? ""
        }
    }

    /// Читает массив offset-ов строк track_row.
    private static func readTrackStringOffsets(_ data: Data, rowBase: Int) -> [UInt16] {
        (0..<trackStringFieldNames.count).compactMap { index in
            try? data.structuralUInt16LE(at: rowBase + 0x5e + index * 2)
        }
    }

    /// Декодирует одно строковое поле track_row и padding после него.
    private static func decodeTrackStringField(
        _ fieldName: String,
        offset: Int,
        offsets: [Int],
        data: Data,
        rowBase: Int,
        rowSize: Int?,
        fields: inout [String: String]
    ) {
        fields["\(fieldName)_offset"] = "\(offset)"

        guard offset >= 0 else {
            fields["\(fieldName)_decode_error"] = "negative_offset"
            return
        }
        if let rowSize, offset >= rowSize {
            fields["\(fieldName)_decode_error"] = "offset_outside_row"
            return
        }

        guard let string = try? readStructuralDeviceSQLString(data, at: rowBase + offset) else {
            fields["\(fieldName)_decode_error"] = "invalid_device_sql_string"
            return
        }

        fields[fieldName] = string.text
        fields["\(fieldName)_kind"] = string.kindHex
        fields["\(fieldName)_encoded_size"] = "\(string.encodedSize)"

        guard let rowSize else { return }
        let nextOffset = offsets
            .filter { $0 > offset && $0 <= rowSize }
            .min() ?? rowSize
        let paddingSize = max(0, nextOffset - offset - string.encodedSize)
        fields["\(fieldName)_padding_size"] = "\(paddingSize)"
        if paddingSize > 0 {
            let paddingStart = rowBase + offset + string.encodedSize
            fields["\(fieldName)_padding_hex"] = (try? data.structuralHex(in: paddingStart..<(paddingStart + paddingSize))) ?? ""
        } else {
            fields["\(fieldName)_padding_hex"] = ""
        }
    }

    /// Читает device_sql_string и возвращает текст вместе с размером encoded-поля.
    private static func readStructuralDeviceSQLString(_ data: Data, at offset: Int) throws -> StructuralDeviceSQLString {
        let kind = try data.structuralUInt8(at: offset)
        if kind & 1 == 1 {
            let length = Int(kind >> 1)
            let textCount = max(0, length - 1)
            let bytes = try data.structuralReadData(in: (offset + 1)..<(offset + 1 + textCount))
            let text = String(data: bytes, encoding: .ascii) ?? ""
            return StructuralDeviceSQLString(
                text: text,
                encodedSize: 1 + textCount,
                kindHex: String(format: "0x%02x", kind)
            )
        }

        let length = Int(try data.structuralUInt16LE(at: offset + 1))
        let textCount = max(0, length - 4)
        let bytes = try data.structuralReadData(in: (offset + 4)..<(offset + 4 + textCount))
        let text: String
        if kind == 0x90 {
            var units: [UInt16] = []
            for index in stride(from: 0, to: bytes.count, by: 2) {
                guard index + 1 < bytes.count else { break }
                let low = UInt16(bytes[bytes.startIndex + index])
                let high = UInt16(bytes[bytes.startIndex + index + 1]) << 8
                units.append(low | high)
            }
            text = String(decoding: units, as: UTF16.self)
        } else {
            text = String(data: bytes, encoding: .ascii) ?? ""
        }
        return StructuralDeviceSQLString(
            text: text,
            encodedSize: length,
            kindHex: String(format: "0x%02x", kind)
        )
    }

    /// Создаёт issue.
    private static func issue(
        _ severity: PioneerDeviceSQLStructuralSeverity,
        _ category: String,
        _ path: String,
        _ message: String
    ) -> PioneerDeviceSQLStructuralIssue {
        PioneerDeviceSQLStructuralIssue(
            severity: severity,
            category: category,
            path: path,
            message: message
        )
    }
}

/// Сырой table descriptor.
private struct PioneerDeviceSQLStructuralTableDescriptor {
    /// Индекс descriptor.
    let descriptorIndex: Int

    /// Table type.
    let type: UInt32

    /// empty_candidate.
    let emptyCandidate: UInt32

    /// first_page.
    let firstPage: UInt32

    /// last_page.
    let lastPage: UInt32

    /// Raw bytes table pointer.
    let descriptorHex: String
}

/// Расшифрованная DeviceSQL-строка для структурной диагностики.
private struct StructuralDeviceSQLString {
    /// Текст строки.
    let text: String

    /// Размер закодированного поля вместе с marker/length.
    let encodedSize: Int

    /// Marker kind/length в hex.
    let kindHex: String
}

private extension Data {
    /// Читает UInt8 по offset.
    func structuralUInt8(at offset: Int) throws -> UInt8 {
        guard offset >= 0, offset < count else {
            throw PioneerDeckExportError.invalidBinaryLayout("UInt8 offset \(offset) за пределами файла.")
        }
        return self[offset]
    }

    /// Читает UInt16 little-endian по offset.
    func structuralUInt16LE(at offset: Int) throws -> UInt16 {
        let bytes = try structuralReadData(in: offset..<(offset + 2))
        return UInt16(bytes[bytes.startIndex]) | (UInt16(bytes[bytes.startIndex + 1]) << 8)
    }

    /// Читает UInt24 little-endian по offset.
    func structuralUInt24LE(at offset: Int) throws -> UInt32 {
        let bytes = try structuralReadData(in: offset..<(offset + 3))
        return UInt32(bytes[bytes.startIndex])
            | (UInt32(bytes[bytes.startIndex + 1]) << 8)
            | (UInt32(bytes[bytes.startIndex + 2]) << 16)
    }

    /// Читает UInt32 little-endian по offset.
    func structuralUInt32LE(at offset: Int) throws -> UInt32 {
        let bytes = try structuralReadData(in: offset..<(offset + 4))
        return UInt32(bytes[bytes.startIndex])
            | (UInt32(bytes[bytes.startIndex + 1]) << 8)
            | (UInt32(bytes[bytes.startIndex + 2]) << 16)
            | (UInt32(bytes[bytes.startIndex + 3]) << 24)
    }

    /// Возвращает hex-представление диапазона.
    func structuralHex(in range: Range<Int>) throws -> String {
        try structuralReadData(in: range)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    /// Читает диапазон байтов с проверкой границ.
    func structuralReadData(in range: Range<Int>) throws -> Data {
        guard range.lowerBound >= 0, range.upperBound <= count else {
            throw PioneerDeckExportError.invalidBinaryLayout("Диапазон \(range) за пределами DeviceSQL файла.")
        }
        return subdata(in: range)
    }
}

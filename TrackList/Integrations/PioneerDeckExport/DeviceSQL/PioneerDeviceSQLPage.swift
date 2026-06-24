//
//  PioneerDeviceSQLPage.swift
//  TrackList
//
//  Сборка страниц DeviceSQL с heap и row index.
//

import Foundation

/// Одна 4096-байтная страница таблицы DeviceSQL.
struct PioneerDeviceSQLPage {
    /// Вид страницы.
    enum Kind {
        /// Пустая index-страница, которую rekordbox обычно ставит первой в цепочке таблицы.
        case index

        /// Data-страница со строками таблицы.
        case data(rows: [Data])

        /// Заполненная нулями candidate-страница из empty_candidate; она не входит в цепочку rows таблицы.
        case emptyCandidate
    }

    /// Размер page header до начала heap.
    static let headerSize = 40

    /// Размер группы row index: 16 offsets + row_present_flags + transaction flags.
    private static let rowGroupSize = 0x24

    /// Индекс страницы в файле.
    let pageIndex: UInt32

    /// Тип таблицы.
    let tableType: PioneerDeviceSQLTableType

    /// Следующая страница цепочки или nil для terminal next_unused_page.
    let nextPage: UInt32?

    /// Содержимое страницы.
    let kind: Kind

    /// Кодирует страницу в бинарный формат DeviceSQL.
    func encoded(pageSize: Int, terminalNextPage: UInt32) throws -> Data {
        switch kind {
        case .index:
            return makeIndexPage(pageSize: pageSize, terminalNextPage: terminalNextPage)
        case let .data(rows):
            return try makeDataPage(rows: rows, pageSize: pageSize, terminalNextPage: terminalNextPage)
        case .emptyCandidate:
            return makeZeroPage(pageSize: pageSize)
        }
    }

    /// Создаёт index-страницу с пустым списком index entries.
    private func makeIndexPage(pageSize: Int, terminalNextPage: UInt32) -> Data {
        var page = makeZeroPage(pageSize: pageSize)
        writeCommonHeader(
            into: &page,
            pageFlags: 0x64,
            numRowOffsets: 0,
            numRows: 0,
            freeSize: 0,
            usedSize: 0,
            terminalNextPage: terminalNextPage
        )

        let nextPageValue = nextPage ?? terminalNextPage
        page.pioneerSetUInt16LE(0x1fff, at: 0x20)
        page.pioneerSetUInt16LE(0x1fff, at: 0x22)
        page.pioneerSetUInt16LE(0x03ec, at: 0x24)
        page.pioneerSetUInt16LE(0, at: 0x26)
        page.pioneerSetUInt32LE(pageIndex, at: 0x28)
        page.pioneerSetUInt32LE(nextPageValue, at: 0x2c)
        page.pioneerSetUInt32LE(0x03ff_ffff, at: 0x30)
        page.pioneerSetUInt32LE(0, at: 0x34)
        page.pioneerSetUInt16LE(0, at: 0x38)
        page.pioneerSetUInt16LE(0x1fff, at: 0x3a)
        return page
    }

    /// Создаёт data-страницу, размещая строки в heap и offsets/bitmap в конце страницы.
    private func makeDataPage(rows: [Data], pageSize: Int, terminalNextPage: UInt32) throws -> Data {
        let rowGroups = Self.rowGroupCount(for: rows.count)
        let rowIndexSize = rowGroups * Self.rowGroupSize
        let usedSize = rows.reduce(0) { $0 + $1.count }
        let freeSize = pageSize - Self.headerSize - usedSize - rowIndexSize
        guard freeSize >= 0 else {
            throw PioneerDeckExportError.invalidBinaryLayout("Строки DeviceSQL data page не помещаются в страницу.")
        }
        guard usedSize <= Int(UInt16.max), freeSize <= Int(UInt16.max), rows.count <= 0x1fff else {
            throw PioneerDeckExportError.invalidBinaryLayout("Поля DeviceSQL page header не помещаются в свои размеры.")
        }

        var page = makeZeroPage(pageSize: pageSize)
        // Reference rekordbox export.pdb помечает tracks data-page как 0x34.
        // По diff это связано с неплотными row slots, но сами slots на этом этапе не меняем.
        let pageFlags: UInt8 = tableType == .tracks ? 0x34 : 0x24
        writeCommonHeader(
            into: &page,
            pageFlags: pageFlags,
            numRowOffsets: UInt16(rows.count),
            numRows: UInt16(rows.count),
            freeSize: UInt16(freeSize),
            usedSize: UInt16(usedSize),
            terminalNextPage: terminalNextPage
        )
        // TODO(DeviceSQL): transaction_row_count/index должны отражать последнюю транзакцию rekordbox; для нового файла пишем весь batch.
        page.pioneerSetUInt16LE(UInt16(rows.count), at: 0x20)
        page.pioneerSetUInt16LE(0, at: 0x22)
        // TODO(DeviceSQL): неизвестные data-page поля offset 0x24/0x26 из rekordbox_pdb.ksy.
        page.pioneerSetUInt16LE(0, at: 0x24)
        page.pioneerSetUInt16LE(0, at: 0x26)

        var rowOffsets: [UInt16] = []
        var heapOffset = 0
        for row in rows {
            guard heapOffset <= Int(UInt16.max) else {
                throw PioneerDeckExportError.invalidBinaryLayout("Offset строки DeviceSQL page не помещается в UInt16.")
            }
            rowOffsets.append(UInt16(heapOffset))
            let rowStart = Self.headerSize + heapOffset
            page.replaceSubrange(rowStart..<(rowStart + row.count), with: row)
            heapOffset += row.count
        }

        writeRowIndex(rowOffsets, into: &page, pageSize: pageSize)
        return page
    }

    /// Пишет общую часть page header.
    private func writeCommonHeader(
        into page: inout Data,
        pageFlags: UInt8,
        numRowOffsets: UInt16,
        numRows: UInt16,
        freeSize: UInt16,
        usedSize: UInt16,
        terminalNextPage: UInt32
    ) {
        let nextPageValue = nextPage ?? terminalNextPage
        let packedRowCounts = UInt32(numRowOffsets) | (UInt32(numRows) << 13)
        page.pioneerSetUInt32LE(pageIndex, at: 0x04)
        page.pioneerSetUInt32LE(tableType.rawValue, at: 0x08)
        page.pioneerSetUInt32LE(nextPageValue, at: 0x0c)
        page.pioneerSetUInt32LE(pageIndex, at: 0x10)
        // TODO(DeviceSQL): неизвестные 4 байта page header после sequence из rekordbox_pdb.ksy.
        page.pioneerSetUInt32LE(0, at: 0x14)
        page[0x18] = UInt8(packedRowCounts & 0xff)
        page[0x19] = UInt8((packedRowCounts >> 8) & 0xff)
        page[0x1a] = UInt8((packedRowCounts >> 16) & 0xff)
        page[0x1b] = pageFlags
        page.pioneerSetUInt16LE(freeSize, at: 0x1c)
        page.pioneerSetUInt16LE(usedSize, at: 0x1e)
    }

    /// Записывает row offsets и bitmap присутствующих строк.
    private func writeRowIndex(_ rowOffsets: [UInt16], into page: inout Data, pageSize: Int) {
        for groupIndex in 0..<Self.rowGroupCount(for: rowOffsets.count) {
            let base = pageSize - (groupIndex * Self.rowGroupSize)
            var presentFlags: UInt16 = 0
            for rowIndex in 0..<16 {
                let absoluteRowIndex = groupIndex * 16 + rowIndex
                guard absoluteRowIndex < rowOffsets.count else { continue }
                let offsetPosition = base - (6 + (2 * rowIndex))
                page.pioneerSetUInt16LE(rowOffsets[absoluteRowIndex], at: offsetPosition)
                presentFlags |= UInt16(1 << rowIndex)
            }
            page.pioneerSetUInt16LE(presentFlags, at: base - 4)
            page.pioneerSetUInt16LE(presentFlags, at: base - 2)
        }
    }

    /// Возвращает количество row index групп.
    static func rowGroupCount(for rowCount: Int) -> Int {
        rowCount == 0 ? 0 : ((rowCount - 1) / 16) + 1
    }

    /// Создаёт нулевую страницу фиксированного размера.
    private func makeZeroPage(pageSize: Int) -> Data {
        Data(repeating: 0, count: pageSize)
    }
}

private extension Data {
    /// Перезаписывает UInt16 little-endian в Data.
    mutating func pioneerSetUInt16LE(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value & 0xff)
        self[offset + 1] = UInt8((value >> 8) & 0xff)
    }

    /// Перезаписывает UInt32 little-endian в Data.
    mutating func pioneerSetUInt32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xff)
        self[offset + 1] = UInt8((value >> 8) & 0xff)
        self[offset + 2] = UInt8((value >> 16) & 0xff)
        self[offset + 3] = UInt8((value >> 24) & 0xff)
    }
}

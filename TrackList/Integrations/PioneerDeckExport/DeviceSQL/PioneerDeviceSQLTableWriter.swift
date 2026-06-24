//
//  PioneerDeviceSQLTableWriter.swift
//  TrackList
//
//  Сборка цепочки страниц одной таблицы DeviceSQL.
//

import Foundation

/// Результат сборки одной DeviceSQL-таблицы.
struct PioneerDeviceSQLTableBuildResult {
    /// Descriptor для table directory.
    let descriptor: PioneerDeviceSQLTableDescriptor

    /// Страницы таблицы в порядке записи в файл.
    let pages: [PioneerDeviceSQLPage]
}

/// Собирает index/data страницы одной таблицы.
struct PioneerDeviceSQLTableWriter {
    /// Тип таблицы.
    let type: PioneerDeviceSQLTableType

    /// Сырые строки таблицы.
    let rows: [Data]

    /// Нужно ли развернуть строки внутри каждой data-страницы под порядок обхода row index внешними parser'ами.
    let preservesExternalRowTraversalOrder: Bool

    /// Создаёт writer одной DeviceSQL-таблицы.
    init(
        type: PioneerDeviceSQLTableType,
        rows: [Data],
        preservesExternalRowTraversalOrder: Bool = false
    ) {
        self.type = type
        self.rows = rows
        self.preservesExternalRowTraversalOrder = preservesExternalRowTraversalOrder
    }

    /// Создаёт цепочку страниц, начиная с указанного индекса.
    func build(startPageIndex: UInt32, pageSize: Int) throws -> PioneerDeviceSQLTableBuildResult {
        let rowChunks = try chunkRows(pageSize: pageSize)
        let indexPageIndex = startPageIndex

        if rowChunks.isEmpty {
            let indexPage = PioneerDeviceSQLPage(
                pageIndex: indexPageIndex,
                tableType: type,
                nextPage: nil,
                kind: .index
            )
            return PioneerDeviceSQLTableBuildResult(
                descriptor: PioneerDeviceSQLTableDescriptor(
                    type: type,
                    firstPage: indexPageIndex,
                    lastPage: indexPageIndex,
                    rowCount: 0
                ),
                pages: [indexPage]
            )
        }

        let firstDataPageIndex = indexPageIndex + 1
        var pages: [PioneerDeviceSQLPage] = [
            PioneerDeviceSQLPage(
                pageIndex: indexPageIndex,
                tableType: type,
                nextPage: firstDataPageIndex,
                kind: .index
            )
        ]

        for chunkIndex in rowChunks.indices {
            let pageIndex = firstDataPageIndex + UInt32(chunkIndex)
            let nextPage = chunkIndex == rowChunks.indices.last ? nil : pageIndex + 1
            let pageRows = rowsForPageStorage(rowChunks[chunkIndex])
            pages.append(
                PioneerDeviceSQLPage(
                    pageIndex: pageIndex,
                    tableType: type,
                    nextPage: nextPage,
                    kind: .data(rows: pageRows)
                )
            )
        }

        return PioneerDeviceSQLTableBuildResult(
            descriptor: PioneerDeviceSQLTableDescriptor(
                type: type,
                firstPage: indexPageIndex,
                lastPage: firstDataPageIndex + UInt32(rowChunks.count - 1),
                rowCount: rows.count
            ),
            pages: pages
        )
    }

    /// Возвращает порядок хранения строк внутри data-страницы.
    private func rowsForPageStorage(_ pageRows: [Data]) -> [Data] {
        guard preservesExternalRowTraversalOrder else { return pageRows }
        // Внешние parser'ы и практический импорт обходят row index от конца группы к началу.
        // Для playlist_entries разворачиваем storage-order страницы, чтобы такой обход совпал с entry_index.
        return pageRows.reversed()
    }

    /// Разбивает строки по data-страницам с учётом heap и row index.
    private func chunkRows(pageSize: Int) throws -> [[Data]] {
        var chunks: [[Data]] = []
        var currentRows: [Data] = []
        var currentUsedSize = 0

        for row in rows {
            guard canFit(rowCount: 1, usedSize: row.count, pageSize: pageSize) else {
                throw PioneerDeckExportError.invalidBinaryLayout("Одна строка \(type.tableName) больше DeviceSQL data page.")
            }

            if !currentRows.isEmpty,
               !canFit(rowCount: currentRows.count + 1, usedSize: currentUsedSize + row.count, pageSize: pageSize) {
                chunks.append(currentRows)
                currentRows = []
                currentUsedSize = 0
            }

            currentRows.append(row)
            currentUsedSize += row.count
        }

        if !currentRows.isEmpty {
            chunks.append(currentRows)
        }
        return chunks
    }

    /// Проверяет, помещается ли набор строк в одну data-страницу.
    private func canFit(rowCount: Int, usedSize: Int, pageSize: Int) -> Bool {
        let indexSize = PioneerDeviceSQLPage.rowGroupCount(for: rowCount) * 0x24
        return PioneerDeviceSQLPage.headerSize + usedSize + indexSize <= pageSize
    }
}

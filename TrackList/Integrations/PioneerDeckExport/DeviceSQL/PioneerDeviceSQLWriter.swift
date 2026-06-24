//
//  PioneerDeviceSQLWriter.swift
//  TrackList
//
//  Минимальный writer настоящего legacy DeviceSQL export.pdb.
//

import Foundation

/// Пишет DeviceSQL export.pdb по layout из Deep-Symmetry/crate-digger rekordbox_pdb.ksy.
public struct PioneerDeviceSQLWriter {
    /// Размер страницы export.pdb.
    public static let pageSize = PioneerDeviceSQLHeader.pageSize

    /// Создаёт DeviceSQL writer.
    public init() {}

    /// Возвращает бинарный export.pdb с полным набором table descriptors legacy DeviceSQL.
    public func write(export: PioneerDeckExport) throws -> Data {
        try export.validate()

        let tableWriters = try makeTableWriters(export: export)
        var descriptors: [PioneerDeviceSQLTableDescriptor] = []
        var pages: [PioneerDeviceSQLPage] = []
        var nextPageIndex: UInt32 = 1

        for tableWriter in tableWriters {
            let result = try tableWriter.build(
                startPageIndex: nextPageIndex,
                pageSize: Self.pageSize
            )
            descriptors.append(result.descriptor)
            pages.append(contentsOf: result.pages)
            nextPageIndex += UInt32(result.pages.count)
        }

        let candidateStartPageIndex = nextPageIndex
        descriptors = addEmptyCandidates(
            to: descriptors,
            candidateStartPageIndex: candidateStartPageIndex,
            pages: &pages
        )

        let nextUnusedPage = UInt32(1 + pages.count)
        let header = PioneerDeviceSQLHeader(
            tableCount: descriptors.count,
            nextUnusedPage: nextUnusedPage,
            sequence: nextUnusedPage
        )

        var data = makeHeaderPage(header: header, descriptors: descriptors)
        for page in pages {
            data.append(try page.encoded(pageSize: Self.pageSize, terminalNextPage: nextUnusedPage))
        }
        return data
    }

    /// Создаёт table writers в порядке page_type из ksy.
    private func makeTableWriters(export: PioneerDeckExport) throws -> [PioneerDeviceSQLTableWriter] {
        [
            PioneerDeviceSQLTableWriter(
                type: .tracks,
                rows: try export.tracks.sorted { $0.id < $1.id }.map {
                    try PioneerDeviceSQLRowWriter.makeTrackRow($0)
                }
            ),
            makePlaceholderTableWriter(type: .genres),
            makePlaceholderTableWriter(type: .artists),
            makePlaceholderTableWriter(type: .albums),
            makePlaceholderTableWriter(type: .labels),
            makePlaceholderTableWriter(type: .keys),
            PioneerDeviceSQLTableWriter(
                type: .colors,
                rows: try export.colors.sorted { $0.id < $1.id }.map {
                    try PioneerDeviceSQLRowWriter.makeColorRow($0)
                }
            ),
            PioneerDeviceSQLTableWriter(
                type: .playlistTree,
                rows: try export.playlists.map { playlist in
                    try PioneerDeviceSQLRowWriter.makePlaylistTreeRow(
                        playlist,
                        sortOrder: 0
                    )
                }
            ),
            PioneerDeviceSQLTableWriter(
                type: .playlistEntries,
                rows: export.playlists.flatMap { playlist in
                    playlist.entries.sorted { $0.position < $1.position }.map { entry in
                        PioneerDeviceSQLRowWriter.makePlaylistEntryRow(
                            playlistId: playlist.id,
                            entry: entry
                        )
                    }
                },
                preservesExternalRowTraversalOrder: true
            ),
            makePlaceholderTableWriter(type: .unknown9),
            makePlaceholderTableWriter(type: .unknown10),
            makePlaceholderTableWriter(type: .unknown11),
            makePlaceholderTableWriter(type: .unknown12),
            makePlaceholderTableWriter(type: .artwork),
            makePlaceholderTableWriter(type: .unknown14),
            makePlaceholderTableWriter(type: .unknown15),
            makePlaceholderTableWriter(type: .columns),
            makePlaceholderTableWriter(type: .historyPlaylists),
            makePlaceholderTableWriter(type: .historyEntries),
            makePlaceholderTableWriter(type: .history)
        ]
    }

    /// Создаёт пустую таблицу с валидной index-page, пока строки этой таблицы не реализованы.
    private func makePlaceholderTableWriter(type: PioneerDeviceSQLTableType) -> PioneerDeviceSQLTableWriter {
        // TODO(DeviceSQL): реализовать row schema для \(type.tableName) по rekordbox_pdb.ksy и reference export.pdb.
        PioneerDeviceSQLTableWriter(type: type, rows: [])
    }

    /// Пишет первую страницу с header и table directory.
    private func makeHeaderPage(
        header: PioneerDeviceSQLHeader,
        descriptors: [PioneerDeviceSQLTableDescriptor]
    ) -> Data {
        var page = Data(repeating: 0, count: Self.pageSize)
        page.pioneerSetUInt32LE(header.unknownSignature, at: 0x00)
        page.pioneerSetUInt32LE(header.pageSize, at: 0x04)
        page.pioneerSetUInt32LE(header.tableCount, at: 0x08)
        page.pioneerSetUInt32LE(header.nextUnusedPage, at: 0x0c)
        page.pioneerSetUInt32LE(header.unknown, at: 0x10)
        page.pioneerSetUInt32LE(header.sequence, at: 0x14)

        var offset = PioneerDeviceSQLHeader.tableDirectoryOffset
        for descriptor in descriptors {
            page.pioneerSetUInt32LE(descriptor.type.rawValue, at: offset)
            page.pioneerSetUInt32LE(descriptor.emptyCandidate, at: offset + 0x04)
            page.pioneerSetUInt32LE(descriptor.firstPage, at: offset + 0x08)
            page.pioneerSetUInt32LE(descriptor.lastPage, at: offset + 0x0c)
            offset += PioneerDeviceSQLHeader.tableDescriptorSize
        }
        return page
    }

    /// Добавляет zero-filled candidate-страницы и связывает с ними последнюю реальную page таблицы.
    private func addEmptyCandidates(
        to descriptors: [PioneerDeviceSQLTableDescriptor],
        candidateStartPageIndex: UInt32,
        pages: inout [PioneerDeviceSQLPage]
    ) -> [PioneerDeviceSQLTableDescriptor] {
        var updatedDescriptors: [PioneerDeviceSQLTableDescriptor] = []

        for (descriptorIndex, descriptor) in descriptors.enumerated() {
            let candidatePageIndex = candidateStartPageIndex + UInt32(descriptorIndex)
            if let lastPageIndex = pages.firstIndex(where: {
                $0.pageIndex == descriptor.lastPage && $0.tableType == descriptor.type
            }) {
                let lastPage = pages[lastPageIndex]
                pages[lastPageIndex] = PioneerDeviceSQLPage(
                    pageIndex: lastPage.pageIndex,
                    tableType: lastPage.tableType,
                    nextPage: candidatePageIndex,
                    kind: lastPage.kind
                )
            }

            updatedDescriptors.append(
                PioneerDeviceSQLTableDescriptor(
                    type: descriptor.type,
                    emptyCandidate: candidatePageIndex,
                    firstPage: descriptor.firstPage,
                    lastPage: descriptor.lastPage,
                    rowCount: descriptor.rowCount
                )
            )
            // TODO(DeviceSQL): изучить структуру free-page chain; reference иногда держит такие pages за EOF.
            pages.append(
                PioneerDeviceSQLPage(
                    pageIndex: candidatePageIndex,
                    tableType: descriptor.type,
                    nextPage: nil,
                    kind: .emptyCandidate
                )
            )
        }
        return updatedDescriptors
    }
}

private extension Data {
    /// Перезаписывает UInt32 little-endian в Data.
    mutating func pioneerSetUInt32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xff)
        self[offset + 1] = UInt8((value >> 8) & 0xff)
        self[offset + 2] = UInt8((value >> 16) & 0xff)
        self[offset + 3] = UInt8((value >> 24) & 0xff)
    }
}

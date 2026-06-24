//
//  PioneerExportExtPDBWriter.swift
//  TrackList
//
//  Минимальный scaffold для exportExt.pdb.
//

import Foundation

/// Пишет минимальный exportExt.pdb scaffold без waveform, beat grid и cue-привязок.
public struct PioneerExportExtPDBWriter {
    /// Magic явно отделяет scaffold от настоящего DeviceSQL.
    private static let scaffoldMagic = "BTEXT001"

    /// Создаёт writer.
    public init() {}

    /// Возвращает бинарный scaffold exportExt.pdb.
    public func write(export: PioneerDeckExport) throws -> Data {
        try export.validate()

        let tables = [
            makeTagsTable(),
            PioneerPDBScaffoldTable(name: "tag_tracks", declaredType: 4, rows: []),
            PioneerPDBScaffoldTable(name: "unknown_7", declaredType: 7, rows: [])
        ]

        return try PioneerPDBScaffoldCodec.write(
            magic: Self.scaffoldMagic,
            kind: "exportExt",
            pageSize: PioneerPDBWriter.pageSize,
            tables: tables
        )
    }

    /// Читает scaffold обратно для unit/readback-тестов.
    public static func readScaffold(from data: Data) throws -> PioneerPDBReadback {
        try PioneerPDBScaffoldCodec.read(from: data, expectedMagic: scaffoldMagic)
    }

    /// Строит стандартный My Tag справочник из каноничного документа.
    private func makeTagsTable() -> PioneerPDBScaffoldTable {
        let groups: [(String, [String])] = [
            ("Genre", ["Acid House", "Deep House", "Techno", "Nu Disco", "Electro House", "Bass Music", "Trap"]),
            ("Components", ["Synth", "Vocal", "Beat", "Sub Bass", "Percussion", "Piano", "Dark", "Upper"]),
            ("Situation", ["Main Floor", "Second Floor", "Lounge", "Mid Night", "Morning", "Build up", "Peak Time", "Build down"]),
            ("Untitled Column", ["My Comment"])
        ]

        var nextId: UInt32 = 1
        let rows = groups.flatMap { groupName, tagNames in
            var groupRows: [Data] = [
                makeTagRow(id: nextId, groupName: groupName, tagName: "")
            ]
            nextId += 1

            groupRows.append(contentsOf: tagNames.map { tagName in
                defer { nextId += 1 }
                return makeTagRow(id: nextId, groupName: groupName, tagName: tagName)
            })
            return groupRows
        }

        return PioneerPDBScaffoldTable(name: "tags", declaredType: 3, rows: rows)
    }

    /// Кодирует строку My Tag справочника.
    private func makeTagRow(id: UInt32, groupName: String, tagName: String) -> Data {
        var writer = BinaryDataWriter()
        writer.appendUInt32LE(id)
        writer.appendLengthPrefixedUTF8(groupName)
        writer.appendLengthPrefixedUTF8(tagName)
        return writer.data
    }
}

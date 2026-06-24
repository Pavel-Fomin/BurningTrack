//
//  PioneerDeviceSQLStructuralDiff.swift
//  TrackList
//
//  Dev-only структурный diff двух DeviceSQL export.pdb.
//

import Foundation

/// Отчёт структурного сравнения reference и generated export.pdb.
public struct PioneerDeviceSQLStructuralDiffReport: Codable, Equatable, Sendable {
    /// Summary по количеству issues.
    public let summary: PioneerDeviceSQLStructuralDiffSummary

    /// Все найденные отличия.
    public let issues: [PioneerDeviceSQLStructuralDiffIssue]

    /// Возвращает человекочитаемый текстовый отчёт.
    public func textReport() -> String {
        var lines: [String] = [
            "Pioneer DeviceSQL Structural Diff",
            "critical: \(summary.criticalCount), warning: \(summary.warningCount), info: \(summary.infoCount)",
            ""
        ]

        for issue in issues {
            lines.append("[\(issue.severity.rawValue.uppercased())] \(issue.category) \(issue.path)")
            lines.append("  \(issue.message)")
            if let reference = issue.referenceValue {
                lines.append("  reference: \(reference)")
            }
            if let generated = issue.generatedValue {
                lines.append("  generated: \(generated)")
            }
        }

        return lines.joined(separator: "\n")
    }
}

/// Summary structural diff.
public struct PioneerDeviceSQLStructuralDiffSummary: Codable, Equatable, Sendable {
    /// Количество critical issues.
    public let criticalCount: Int

    /// Количество warning issues.
    public let warningCount: Int

    /// Количество info issues.
    public let infoCount: Int

    /// Найдены ли critical issues.
    public let hasCriticalIssues: Bool
}

/// Одно отличие structural diff.
public struct PioneerDeviceSQLStructuralDiffIssue: Codable, Equatable, Sendable {
    /// Серьёзность.
    public let severity: PioneerDeviceSQLStructuralSeverity

    /// Категория.
    public let category: String

    /// Путь в дампе.
    public let path: String

    /// Сообщение.
    public let message: String

    /// Значение reference, если применимо.
    public let referenceValue: String?

    /// Значение generated, если применимо.
    public let generatedValue: String?
}

/// Сравнивает два структурных дампа DeviceSQL.
public enum PioneerDeviceSQLStructuralDiff {
    /// Таблицы, без которых generated export.pdb точно не должен считаться минимально пригодным.
    private static let coreTableTypes: Set<UInt32> = [0, 6, 7, 8]

    /// Сравнивает reference и generated dump.
    public static func compare(
        reference: PioneerDeviceSQLStructuralDump,
        generated: PioneerDeviceSQLStructuralDump
    ) -> PioneerDeviceSQLStructuralDiffReport {
        var issues: [PioneerDeviceSQLStructuralDiffIssue] = []
        compareHeader(reference: reference, generated: generated, issues: &issues)
        appendDumpIssues(reference: reference, generated: generated, issues: &issues)
        compareTables(reference: reference, generated: generated, issues: &issues)

        let criticalCount = issues.filter { $0.severity == .critical }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count

        return PioneerDeviceSQLStructuralDiffReport(
            summary: PioneerDeviceSQLStructuralDiffSummary(
                criticalCount: criticalCount,
                warningCount: warningCount,
                infoCount: infoCount,
                hasCriticalIssues: criticalCount > 0
            ),
            issues: issues
        )
    }

    /// Сравнивает header и file-level поля.
    private static func compareHeader(
        reference: PioneerDeviceSQLStructuralDump,
        generated: PioneerDeviceSQLStructuralDump,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        appendIfDifferent(&issues, .info, "file_size", "$.fileSize", "Размеры файлов отличаются.", reference.fileSize, generated.fileSize)
        appendIfDifferent(&issues, .info, "file_pages", "$.filePageCount", "Количество страниц отличается.", reference.filePageCount, generated.filePageCount)
        appendIfDifferent(&issues, .critical, "header", "$.header.unknownSignature", "Первое поле header отличается.", reference.header.unknownSignature, generated.header.unknownSignature)
        appendIfDifferent(&issues, .critical, "header", "$.header.pageSize", "len_page отличается.", reference.header.pageSize, generated.header.pageSize)
        appendIfDifferent(&issues, .info, "header", "$.header.tableCount", "Количество table pointers отличается.", reference.header.tableCount, generated.header.tableCount)
        appendIfDifferent(&issues, .warning, "header", "$.header.nextUnusedPage", "next_unused_page отличается.", reference.header.nextUnusedPage, generated.header.nextUnusedPage)
        appendIfDifferent(&issues, .critical, "header_unknown", "$.header.unknown0x10", "Неизвестное поле header offset 0x10 отличается.", reference.header.unknown0x10, generated.header.unknown0x10)
        appendIfDifferent(&issues, .info, "header_sequence", "$.header.sequence", "sequence отличается.", reference.header.sequence, generated.header.sequence)
        appendIfDifferent(&issues, .critical, "header", "$.header.gapHex", "Header gap offset 0x18...0x1b отличается.", reference.header.gapHex, generated.header.gapHex)
    }

    /// Переносит внутренние ошибки дампов в diff report.
    private static func appendDumpIssues(
        reference: PioneerDeviceSQLStructuralDump,
        generated: PioneerDeviceSQLStructuralDump,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        for issue in reference.issues {
            issues.append(
                makeIssue(
                    .warning,
                    "reference_dump_issue",
                    issue.path,
                    "Reference dump issue: \(issue.message)",
                    issue.severity.rawValue,
                    nil
                )
            )
        }
        for issue in generated.issues {
            issues.append(
                makeIssue(
                    issue.severity,
                    "generated_dump_issue",
                    issue.path,
                    "Generated dump issue: \(issue.message)",
                    nil,
                    issue.severity.rawValue
                )
            )
        }
    }

    /// Сравнивает таблицы, descriptors, страницы и row layout.
    private static func compareTables(
        reference: PioneerDeviceSQLStructuralDump,
        generated: PioneerDeviceSQLStructuralDump,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        let referenceTables = Dictionary(uniqueKeysWithValues: reference.tables.map { ($0.type, $0) })
        let generatedTables = Dictionary(uniqueKeysWithValues: generated.tables.map { ($0.type, $0) })
        let allTypes = Set(referenceTables.keys).union(generatedTables.keys).sorted()

        for type in allTypes {
            let name = PioneerDeviceSQLStructuralDumpBuilder.tableName(for: type)
            let path = "$.tables[\(name)]"
            let referenceTable = referenceTables[type]
            let generatedTable = generatedTables[type]

            if referenceTable != nil, generatedTable == nil {
                let severity: PioneerDeviceSQLStructuralSeverity = coreTableTypes.contains(type) ? .critical : .warning
                issues.append(
                    makeIssue(
                        severity,
                        "missing_table",
                        path,
                        "Generated export.pdb не содержит таблицу из reference.",
                        name,
                        nil
                    )
                )
                continue
            }

            if referenceTable == nil, generatedTable != nil {
                issues.append(
                    makeIssue(
                        .info,
                        "extra_table",
                        path,
                        "Generated export.pdb содержит таблицу, которой нет в reference.",
                        nil,
                        name
                    )
                )
                continue
            }

            guard let referenceTable, let generatedTable else { continue }
            compareTableDescriptors(referenceTable: referenceTable, generatedTable: generatedTable, issues: &issues)
            comparePageStructure(referenceTable: referenceTable, generatedTable: generatedTable, issues: &issues)
            compareRowLayout(referenceTable: referenceTable, generatedTable: generatedTable, issues: &issues)
        }
    }

    /// Сравнивает table descriptor поля.
    private static func compareTableDescriptors(
        referenceTable: PioneerDeviceSQLStructuralTable,
        generatedTable: PioneerDeviceSQLStructuralTable,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        let path = "$.tables[\(referenceTable.name)].descriptor"
        appendIfDifferent(&issues, .warning, "table_descriptor", path + ".emptyCandidate", "empty_candidate отличается.", referenceTable.emptyCandidate, generatedTable.emptyCandidate)
        appendIfDifferent(&issues, .info, "table_descriptor", path + ".firstPage", "first_page отличается.", referenceTable.firstPage, generatedTable.firstPage)
        appendIfDifferent(&issues, .info, "table_descriptor", path + ".lastPage", "last_page отличается.", referenceTable.lastPage, generatedTable.lastPage)
        appendIfDifferent(&issues, .info, "table_descriptor", path + ".pageCount", "Количество страниц таблицы отличается.", referenceTable.pages.count, generatedTable.pages.count)
    }

    /// Сравнивает page headers и unknown fields.
    private static func comparePageStructure(
        referenceTable: PioneerDeviceSQLStructuralTable,
        generatedTable: PioneerDeviceSQLStructuralTable,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        let referenceFlags = Set(referenceTable.pages.map(\.pageFlags))
        let generatedFlags = Set(generatedTable.pages.map(\.pageFlags))
        if !generatedFlags.isSubset(of: referenceFlags) {
            issues.append(
                makeIssue(
                    .critical,
                    "page_flags",
                    "$.tables[\(generatedTable.name)].pages.pageFlags",
                    "Generated содержит page_flags, которых нет в reference для этой таблицы.",
                    referenceFlags.sorted().map { String(format: "0x%02x", $0) }.joined(separator: ","),
                    generatedFlags.sorted().map { String(format: "0x%02x", $0) }.joined(separator: ",")
                )
            )
        }

        compareUnknownPageField(
            referenceValues: Set(referenceTable.pages.map(\.unknown0x14)),
            generatedValues: Set(generatedTable.pages.map(\.unknown0x14)),
            tableName: generatedTable.name,
            field: "unknown0x14",
            severity: .critical,
            issues: &issues
        )

        compareUnknownPageField(
            referenceValues: Set(referenceTable.pages.compactMap(\.dataHeader?.unknown0x24)),
            generatedValues: Set(generatedTable.pages.compactMap(\.dataHeader?.unknown0x24)),
            tableName: generatedTable.name,
            field: "dataHeader.unknown0x24",
            allowMissingGeneratedDataPages: generatedTable.pages.reduce(0) { $0 + Int($1.numRows) } == 0,
            severity: .critical,
            issues: &issues
        )

        compareUnknownPageField(
            referenceValues: Set(referenceTable.pages.compactMap(\.dataHeader?.unknown0x26)),
            generatedValues: Set(generatedTable.pages.compactMap(\.dataHeader?.unknown0x26)),
            tableName: generatedTable.name,
            field: "dataHeader.unknown0x26",
            allowMissingGeneratedDataPages: generatedTable.pages.reduce(0) { $0 + Int($1.numRows) } == 0,
            severity: .critical,
            issues: &issues
        )

        appendIfDifferent(
            &issues,
            .info,
            "row_counts",
            "$.tables[\(generatedTable.name)].rows",
            "Количество строк отличается; это допустимо, если reference и generated сделаны из разных наборов треков.",
            referenceTable.pages.reduce(0) { $0 + Int($1.numRows) },
            generatedTable.pages.reduce(0) { $0 + Int($1.numRows) }
        )
    }

    /// Сравнивает layout строк без привязки к пользовательским metadata.
    private static func compareRowLayout(
        referenceTable: PioneerDeviceSQLStructuralTable,
        generatedTable: PioneerDeviceSQLStructuralTable,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        let referenceSizes = rowSizeSet(referenceTable)
        let generatedSizes = rowSizeSet(generatedTable)
        if !referenceSizes.isEmpty, !generatedSizes.isEmpty, referenceSizes != generatedSizes {
            let severity: PioneerDeviceSQLStructuralSeverity
            let message: String
            if generatedTable.type == 8 {
                severity = .critical
                message = "Набор оценочных размеров строк отличается."
            } else if generatedTable.type == 7 {
                severity = .info
                message = "Размер playlist_tree_row зависит от имени и выравнивания; декодированные поля сравниваются отдельно."
            } else {
                severity = .warning
                message = "Набор оценочных размеров строк отличается."
            }
            issues.append(
                makeIssue(
                    severity,
                    "row_layout",
                    "$.tables[\(generatedTable.name)].presentRows.estimatedRowSize",
                    message,
                    referenceSizes.sorted().map(String.init).joined(separator: ","),
                    generatedSizes.sorted().map(String.init).joined(separator: ",")
                )
            )
        }

        if generatedTable.type == 7 {
            comparePlaylistTreeRows(referenceTable: referenceTable, generatedTable: generatedTable, issues: &issues)
        }
        if generatedTable.type == 6 {
            compareColorRows(referenceTable: referenceTable, generatedTable: generatedTable, issues: &issues)
        }
        if generatedTable.type == 0 {
            compareTrackRows(referenceTable: referenceTable, generatedTable: generatedTable, issues: &issues)
        }

        if generatedTable.type == 8 {
            let invalidPlaylistEntrySizes = generatedTable.pages
                .flatMap(\.presentRows)
                .compactMap(\.estimatedRowSize)
                .filter { $0 != 12 }
            if !invalidPlaylistEntrySizes.isEmpty {
                issues.append(
                    makeIssue(
                        .critical,
                        "row_layout",
                        "$.tables[playlist_entries].presentRows.estimatedRowSize",
                        "playlist_entry_row должен быть 12 байт: entry_index, track_id, playlist_id.",
                        "12",
                        Set(invalidPlaylistEntrySizes).sorted().map(String.init).joined(separator: ",")
                    )
                )
            }
        }
    }

    /// Сравнивает подтверждённые поля track_row из rekordbox_pdb.ksy.
    private static func compareTrackRows(
        referenceTable: PioneerDeviceSQLStructuralTable,
        generatedTable: PioneerDeviceSQLStructuralTable,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        let referenceRows = decodedRows(referenceTable, kind: "track")
        let generatedRows = decodedRows(generatedTable, kind: "track")
        let referenceById = Dictionary(uniqueKeysWithValues: referenceRows.compactMap { row in
            row.id.map { ($0, row) }
        })
        let generatedById = Dictionary(uniqueKeysWithValues: generatedRows.compactMap { row in
            row.id.map { ($0, row) }
        })
        let commonIds = Set(referenceById.keys).intersection(generatedById.keys).sorted()

        if commonIds.isEmpty {
            issues.append(
                makeIssue(
                    .warning,
                    "track_row",
                    "$.tables[tracks].presentRows.decoded.id",
                    "У reference и generated нет общих track_id; tracks field-level diff сопоставляет строки только по порядку.",
                    referenceById.keys.sorted().map(String.init).joined(separator: ","),
                    generatedById.keys.sorted().map(String.init).joined(separator: ",")
                )
            )
            let comparedCount = min(referenceRows.count, generatedRows.count)
            for index in 0..<comparedCount {
                compareSingleTrackRow(
                    referenceRow: referenceRows[index],
                    generatedRow: generatedRows[index],
                    path: "$.tables[tracks].presentRows[\(index)].decoded",
                    issues: &issues
                )
            }
            return
        }

        let missingIds = Set(referenceById.keys).subtracting(generatedById.keys).sorted()
        if !missingIds.isEmpty {
            issues.append(
                makeIssue(
                    .info,
                    "track_row",
                    "$.tables[tracks].presentRows.decoded.id",
                    "Generated не содержит часть track_id из reference; это допустимо для разных наборов треков.",
                    missingIds.map(String.init).joined(separator: ","),
                    nil
                )
            )
        }

        for trackId in commonIds {
            guard
                let referenceRow = referenceById[trackId],
                let generatedRow = generatedById[trackId]
            else {
                continue
            }
            compareSingleTrackRow(
                referenceRow: referenceRow,
                generatedRow: generatedRow,
                path: "$.tables[tracks].presentRows[id=\(trackId)].decoded",
                issues: &issues
            )
        }
    }

    /// Сравнивает одну пару track_row.
    private static func compareSingleTrackRow(
        referenceRow: PioneerDeviceSQLStructuralDecodedRow,
        generatedRow: PioneerDeviceSQLStructuralDecodedRow,
        path: String,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        appendIfDifferent(&issues, .warning, "track_row", path + ".id", "track id отличается.", referenceRow.id, generatedRow.id)
        for field in trackFieldComparisonOrder {
            compareDecodedTrackField(
                field,
                severity: trackFieldSeverity(field),
                path: path,
                referenceRow: referenceRow,
                generatedRow: generatedRow,
                issues: &issues
            )
        }
    }

    /// Имена строковых полей track_row в порядке ofs_strings.
    private static let trackStringComparisonNames = [
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

    /// Порядок полей track_row в подробном diff.
    private static let trackFieldComparisonOrder: [String] = {
        var fields = [
            "row_size",
            "subtype",
            "index_shift",
            "bitmask",
            "bitmask_hex",
            "sample_rate",
            "composer_id",
            "file_size",
            "unknown_id",
            "unknown_0x14_hex",
            "unknown_0x18",
            "unknown_0x18_hex",
            "unknown_0x1a",
            "unknown_0x1a_hex",
            "artwork_id",
            "key_id",
            "original_artist_id",
            "label_id",
            "remixer_id",
            "bitrate",
            "track_number",
            "tempo_x100",
            "bpm",
            "genre_id",
            "album_id",
            "artist_id",
            "track_id",
            "disc_number",
            "play_count",
            "year",
            "sample_depth",
            "duration",
            "unknown_0x56",
            "unknown_0x56_hex",
            "color_id",
            "rating",
            "unknown_0x5a",
            "unknown_0x5a_hex",
            "unknown_0x5c",
            "unknown_0x5c_hex",
            "ofs_strings_hex"
        ]

        for name in trackStringComparisonNames {
            fields.append(contentsOf: [
                name,
                "\(name)_kind",
                "\(name)_encoded_size",
                "\(name)_padding_size",
                "\(name)_offset"
            ])
        }
        return fields
    }()

    /// Поля track_row, которые сильнее всего похожи на структурные инварианты или обязательные audio/file параметры.
    private static let trackWarningFields: Set<String> = [
        "row_size",
        "index_shift",
        "bitmask",
        "sample_rate",
        "file_size",
        "unknown_id",
        "unknown_0x14_hex",
        "unknown_0x18",
        "unknown_0x18_hex",
        "unknown_0x1a",
        "unknown_0x1a_hex",
        "bitrate",
        "tempo_x100",
        "bpm",
        "sample_depth",
        "duration",
        "unknown_0x56",
        "unknown_0x56_hex",
        "unknown_0x5a",
        "unknown_0x5a_hex",
        "unknown_0x5c",
        "unknown_0x5c_hex",
        "kuvo_public",
        "autoload_hot_cues",
        "analyze_path",
        "analyze_date",
        "file_path"
    ]

    /// Возвращает классификацию отличия для track_row field-level diff.
    private static func trackFieldSeverity(_ field: String) -> PioneerDeviceSQLStructuralSeverity {
        if field == "subtype" {
            return .critical
        }
        if trackWarningFields.contains(field) {
            return .warning
        }
        return .info
    }

    /// Сравнивает подтверждённые поля color_row из rekordbox_pdb.ksy.
    private static func compareColorRows(
        referenceTable: PioneerDeviceSQLStructuralTable,
        generatedTable: PioneerDeviceSQLStructuralTable,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        let referenceRows = decodedRows(referenceTable, kind: "color").sorted { ($0.id ?? 0) < ($1.id ?? 0) }
        let generatedRows = decodedRows(generatedTable, kind: "color").sorted { ($0.id ?? 0) < ($1.id ?? 0) }
        let comparedCount = min(referenceRows.count, generatedRows.count)

        for index in 0..<comparedCount {
            let path = "$.tables[colors].presentRows[\(index)].decoded"
            let referenceRow = referenceRows[index]
            let generatedRow = generatedRows[index]
            appendIfDifferent(&issues, .warning, "color_row", path + ".id", "color id отличается.", referenceRow.id, generatedRow.id)
            compareDecodedColorField("unknown_0x00_hex", severity: .warning, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedColorField("unknown_0x04", severity: .warning, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedColorField("color_id", severity: .warning, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedColorField("unknown_0x07", severity: .warning, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedColorField("name", severity: .info, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedColorField("string_encoded_size", severity: .info, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedColorField("padding_size", severity: .info, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedColorField("row_size", severity: .info, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
        }
    }

    /// Сравнивает подтверждённые поля playlist_tree_row из rekordbox_pdb.ksy.
    private static func comparePlaylistTreeRows(
        referenceTable: PioneerDeviceSQLStructuralTable,
        generatedTable: PioneerDeviceSQLStructuralTable,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        let referenceRows = decodedRows(referenceTable, kind: "playlist_tree")
        let generatedRows = decodedRows(generatedTable, kind: "playlist_tree")
        let comparedCount = min(referenceRows.count, generatedRows.count)

        for index in 0..<comparedCount {
            let path = "$.tables[playlist_tree].presentRows[\(index)].decoded"
            let referenceRow = referenceRows[index]
            let generatedRow = generatedRows[index]
            appendIfDifferent(&issues, .warning, "playlist_tree_row", path + ".id", "playlist_tree id отличается.", referenceRow.id, generatedRow.id)
            compareDecodedField("parent_id", severity: .warning, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedField("unknown_0x04_hex", severity: .warning, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedField("sort_order", severity: .warning, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedField("raw_is_folder", severity: .warning, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedField("is_folder", severity: .warning, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedField("name", severity: .info, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedField("string_encoded_size", severity: .info, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedField("padding_size", severity: .info, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
            compareDecodedField("row_size", severity: .info, path: path, referenceRow: referenceRow, generatedRow: generatedRow, issues: &issues)
        }
    }

    /// Возвращает декодированные строки заданного типа.
    private static func decodedRows(
        _ table: PioneerDeviceSQLStructuralTable,
        kind: String
    ) -> [PioneerDeviceSQLStructuralDecodedRow] {
        table.pages
            .flatMap(\.presentRows)
            .compactMap(\.decoded)
            .filter { $0.kind == kind }
    }

    /// Сравнивает одно декодированное поле.
    private static func compareDecodedField(
        _ field: String,
        severity: PioneerDeviceSQLStructuralSeverity,
        path: String,
        referenceRow: PioneerDeviceSQLStructuralDecodedRow,
        generatedRow: PioneerDeviceSQLStructuralDecodedRow,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        appendIfDifferent(
            &issues,
            severity,
            "playlist_tree_row",
            path + ".fields.\(field)",
            "playlist_tree \(field) отличается.",
            referenceRow.fields[field],
            generatedRow.fields[field]
        )
    }

    /// Сравнивает одно декодированное поле color_row.
    private static func compareDecodedColorField(
        _ field: String,
        severity: PioneerDeviceSQLStructuralSeverity,
        path: String,
        referenceRow: PioneerDeviceSQLStructuralDecodedRow,
        generatedRow: PioneerDeviceSQLStructuralDecodedRow,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        appendIfDifferent(
            &issues,
            severity,
            "color_row",
            path + ".fields.\(field)",
            "color \(field) отличается.",
            referenceRow.fields[field],
            generatedRow.fields[field]
        )
    }

    /// Сравнивает одно декодированное поле track_row.
    private static func compareDecodedTrackField(
        _ field: String,
        severity: PioneerDeviceSQLStructuralSeverity,
        path: String,
        referenceRow: PioneerDeviceSQLStructuralDecodedRow,
        generatedRow: PioneerDeviceSQLStructuralDecodedRow,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        let referenceValue = referenceRow.fields[field]
        let generatedValue = generatedRow.fields[field]
        guard referenceValue != generatedValue else { return }
        if isTrackFixedField(field, referenceRow: referenceRow, generatedRow: generatedRow) {
            issues.append(
                makeIssue(
                    severity,
                    "track_fixed_field",
                    path + ".fields.\(field)",
                    trackFixedFieldMessage(field, referenceRow: referenceRow, generatedRow: generatedRow),
                    decoratedTrackFixedFieldValue(field, row: referenceRow),
                    decoratedTrackFixedFieldValue(field, row: generatedRow)
                )
            )
            return
        }
        issues.append(
            makeIssue(
                severity,
                "track_row",
                path + ".fields.\(field)",
                "track \(field) отличается.",
                referenceValue,
                generatedValue
            )
        )
    }

    /// Проверяет, есть ли у поля fixed-field metadata из structural dump.
    private static func isTrackFixedField(
        _ field: String,
        referenceRow: PioneerDeviceSQLStructuralDecodedRow,
        generatedRow: PioneerDeviceSQLStructuralDecodedRow
    ) -> Bool {
        referenceRow.fields["\(field)_raw_hex"] != nil || generatedRow.fields["\(field)_raw_hex"] != nil
    }

    /// Формирует сообщение с offset и координатами строки для fixed-field diff.
    private static func trackFixedFieldMessage(
        _ field: String,
        referenceRow: PioneerDeviceSQLStructuralDecodedRow,
        generatedRow: PioneerDeviceSQLStructuralDecodedRow
    ) -> String {
        let offset = referenceRow.fields["\(field)_offset"] ?? generatedRow.fields["\(field)_offset"] ?? "unknown"
        let referenceRowIndex = referenceRow.fields["row_index"] ?? "unknown"
        let generatedRowIndex = generatedRow.fields["row_index"] ?? "unknown"
        let referenceTrackId = referenceRow.fields["track_id"] ?? referenceRow.id.map(String.init) ?? "unknown"
        let generatedTrackId = generatedRow.fields["track_id"] ?? generatedRow.id.map(String.init) ?? "unknown"
        return "track fixed field \(field) отличается; offset \(offset); reference track_id=\(referenceTrackId) row_index=\(referenceRowIndex); generated track_id=\(generatedTrackId) row_index=\(generatedRowIndex)."
    }

    /// Формирует значение fixed-field diff с decoded и raw bytes.
    private static func decoratedTrackFixedFieldValue(
        _ field: String,
        row: PioneerDeviceSQLStructuralDecodedRow
    ) -> String {
        let decoded = row.fields[field] ?? ""
        let raw = row.fields["\(field)_raw_hex"] ?? ""
        return "decoded=\(decoded) raw=\(raw)"
    }

    /// Сравнивает наборы неизвестных page fields.
    private static func compareUnknownPageField<T: Comparable & CustomStringConvertible>(
        referenceValues: Set<T>,
        generatedValues: Set<T>,
        tableName: String,
        field: String,
        allowMissingGeneratedDataPages: Bool = false,
        severity: PioneerDeviceSQLStructuralSeverity,
        issues: inout [PioneerDeviceSQLStructuralDiffIssue]
    ) {
        guard referenceValues != generatedValues else { return }
        if allowMissingGeneratedDataPages, generatedValues.isEmpty {
            issues.append(
                makeIssue(
                    .info,
                    "page_unknown_field",
                    "$.tables[\(tableName)].pages.\(field)",
                    "Generated table пока пустая, поэтому data-page unknown field отсутствует.",
                    referenceValues.sorted().map(\.description).joined(separator: ","),
                    ""
                )
            )
            return
        }
        issues.append(
            makeIssue(
                severity,
                "page_unknown_field",
                "$.tables[\(tableName)].pages.\(field)",
                "Набор неизвестных page field значений отличается системно.",
                referenceValues.sorted().map(\.description).joined(separator: ","),
                generatedValues.sorted().map(\.description).joined(separator: ",")
            )
        )
    }

    /// Возвращает набор оценочных размеров строк таблицы.
    private static func rowSizeSet(_ table: PioneerDeviceSQLStructuralTable) -> Set<Int> {
        Set(table.pages.flatMap(\.presentRows).compactMap(\.estimatedRowSize))
    }

    /// Добавляет issue, если значения отличаются.
    private static func appendIfDifferent<T: Equatable>(
        _ issues: inout [PioneerDeviceSQLStructuralDiffIssue],
        _ severity: PioneerDeviceSQLStructuralSeverity,
        _ category: String,
        _ path: String,
        _ message: String,
        _ referenceValue: T,
        _ generatedValue: T
    ) {
        guard referenceValue != generatedValue else { return }
        issues.append(
            makeIssue(
                severity,
                category,
                path,
                message,
                String(describing: referenceValue),
                String(describing: generatedValue)
            )
        )
    }

    /// Создаёт diff issue.
    private static func makeIssue(
        _ severity: PioneerDeviceSQLStructuralSeverity,
        _ category: String,
        _ path: String,
        _ message: String,
        _ referenceValue: String?,
        _ generatedValue: String?
    ) -> PioneerDeviceSQLStructuralDiffIssue {
        PioneerDeviceSQLStructuralDiffIssue(
            severity: severity,
            category: category,
            path: path,
            message: message,
            referenceValue: referenceValue,
            generatedValue: generatedValue
        )
    }
}

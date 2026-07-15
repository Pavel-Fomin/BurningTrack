#!/usr/bin/env swift

//
//  generate_sqlite_schema_docs.swift
//  TrackList
//
//  Генерация документации схемы SQLite.
//
//  Created by Pavel Fomin on 06.07.2026.

import Foundation

// Ошибка скрипта с понятным текстом для developer-команды.
struct ScriptFailure: Error, CustomStringConvertible {
    let description: String
}

// Корень репозитория ожидается текущей рабочей директорией при запуске скрипта.
let repositoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

// Выходной файл можно переопределить, но по умолчанию документация пишется в Architecture.
let outputPath: String
let arguments = Array(CommandLine.arguments.dropFirst())
if arguments.isEmpty {
    outputPath = "Documentation/Architecture/SQLite Schema.generated.md"
} else if arguments.count == 2, arguments[0] == "--output" {
    outputPath = arguments[1]
} else {
    throw ScriptFailure(
        description: "Использование: xcrun swift Scripts/generate_sqlite_schema_docs.swift [--output path]"
    )
}

func resolveRepositoryPath(_ path: String) -> URL {
    if path.hasPrefix("/") {
        return URL(fileURLWithPath: path)
    }

    return repositoryURL.appendingPathComponent(path)
}

let outputURL = resolveRepositoryPath(outputPath)

// Компилируем временный helper из реальных файлов SQLite-слоя, чтобы не дублировать миграции вручную.
let requiredSources = [
    "TrackList/Persistence/Database/DatabaseError.swift",
    "TrackList/Persistence/Database/Core/DatabaseValueCodec.swift",
    "TrackList/Persistence/Database/Core/DatabaseDateCodec.swift",
    "TrackList/Persistence/Database/Core/DatabaseRowReader.swift",
    "TrackList/Persistence/Database/Core/DatabaseStatement.swift",
    "TrackList/Persistence/Database/Core/DatabaseConnection.swift",
    "TrackList/Persistence/Database/Core/DatabaseExecutor.swift",
    "TrackList/Persistence/Database/DatabaseMigration.swift",
    "TrackList/Persistence/Database/DatabaseMigrator.swift"
]

let sourceURLs = requiredSources.map(resolveRepositoryPath)
for sourceURL in sourceURLs where FileManager.default.fileExists(atPath: sourceURL.path) == false {
    throw ScriptFailure(description: "Не найден исходный файл SQLite-слоя: \(sourceURL.path)")
}

let temporaryDirectory = FileManager.default.temporaryDirectory
    .appendingPathComponent("burningtrack-sqlite-schema-docs-\(UUID().uuidString)")
try FileManager.default.createDirectory(
    at: temporaryDirectory,
    withIntermediateDirectories: true
)

defer {
    try? FileManager.default.removeItem(at: temporaryDirectory)
}

let helperSourceURL = temporaryDirectory.appendingPathComponent("main.swift")
let helperExecutableURL = temporaryDirectory.appendingPathComponent("generate-sqlite-schema-docs")
let temporaryDatabaseURL = temporaryDirectory.appendingPathComponent("schema.sqlite")

let helperSource = #"""
import Foundation

struct TableInfo {
    let name: String
}

struct ColumnInfo {
    let name: String
    let type: String
    let isNotNull: Bool
    let defaultValue: String?
    let primaryKeyPosition: Int
    let hiddenKind: Int
}

struct ForeignKeyInfo {
    let id: Int
    let sequence: Int
    let targetTable: String
    let fromColumn: String
    let toColumn: String
    let onUpdate: String
    let onDelete: String
    let match: String
}

struct IndexInfo {
    let name: String
    let isUnique: Bool
    let origin: String
    let isPartial: Bool
    let columns: [String]
}

func quotedIdentifier(_ value: String) -> String {
    "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
}

func markdownValue(_ value: String?) -> String {
    guard let value, value.isEmpty == false else {
        return "-"
    }

    return value
        .replacingOccurrences(of: "|", with: "\\|")
        .replacingOccurrences(of: "\n", with: "<br>")
}

func yesNo(_ value: Bool) -> String {
    value ? "yes" : "no"
}

func fetchTables(database: DatabaseConnection) throws -> [TableInfo] {
    let statement = try database.prepare(
        """
        SELECT name
        FROM sqlite_schema
        WHERE type = 'table'
          AND name NOT LIKE 'sqlite_%'
        ORDER BY name COLLATE NOCASE;
        """
    )
    var result: [TableInfo] = []

    while try statement.step() == .row {
        let row = try statement.rowReader()
        result.append(TableInfo(name: try row.requiredString(at: 0)))
    }

    return result
}

func fetchColumns(database: DatabaseConnection, tableName: String) throws -> [ColumnInfo] {
    let statement = try database.prepare("PRAGMA table_xinfo(\(quotedIdentifier(tableName)));")
    var result: [ColumnInfo] = []

    while try statement.step() == .row {
        let row = try statement.rowReader()
        result.append(
            ColumnInfo(
                name: try row.requiredString(at: 1),
                type: row.string(at: 2) ?? "",
                isNotNull: (row.int(at: 3) ?? 0) != 0,
                defaultValue: row.string(at: 4),
                primaryKeyPosition: row.int(at: 5) ?? 0,
                hiddenKind: row.int(at: 6) ?? 0
            )
        )
    }

    return result
}

func fetchForeignKeys(database: DatabaseConnection, tableName: String) throws -> [ForeignKeyInfo] {
    let statement = try database.prepare("PRAGMA foreign_key_list(\(quotedIdentifier(tableName)));")
    var result: [ForeignKeyInfo] = []

    while try statement.step() == .row {
        let row = try statement.rowReader()
        result.append(
            ForeignKeyInfo(
                id: try row.requiredInt(at: 0),
                sequence: try row.requiredInt(at: 1),
                targetTable: try row.requiredString(at: 2),
                fromColumn: try row.requiredString(at: 3),
                toColumn: try row.requiredString(at: 4),
                onUpdate: try row.requiredString(at: 5),
                onDelete: try row.requiredString(at: 6),
                match: try row.requiredString(at: 7)
            )
        )
    }

    return result
}

func fetchIndexColumns(database: DatabaseConnection, indexName: String) throws -> [String] {
    let statement = try database.prepare("PRAGMA index_info(\(quotedIdentifier(indexName)));")
    var result: [String] = []

    while try statement.step() == .row {
        let row = try statement.rowReader()
        result.append(try row.requiredString(at: 2))
    }

    return result
}

func fetchIndexes(database: DatabaseConnection, tableName: String) throws -> [IndexInfo] {
    let statement = try database.prepare("PRAGMA index_list(\(quotedIdentifier(tableName)));")
    var result: [IndexInfo] = []

    while try statement.step() == .row {
        let row = try statement.rowReader()
        let name = try row.requiredString(at: 1)
        result.append(
            IndexInfo(
                name: name,
                isUnique: (row.int(at: 2) ?? 0) != 0,
                origin: row.string(at: 3) ?? "",
                isPartial: (row.int(at: 4) ?? 0) != 0,
                columns: try fetchIndexColumns(database: database, indexName: name)
            )
        )
    }

    return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
}

func makeMarkdown(database: DatabaseConnection) throws -> String {
    let tables = try fetchTables(database: database)
    var lines: [String] = [
        "# SQLite Schema (Generated)",
        "",
        "> Этот файл является снимком фактической SQLite-схемы.",
        "> Он генерируется из временной базы после применения migrations.",
        "> Не редактировать вручную: любые изменения будут перезаписаны при следующей генерации.",
        "",
        "## Tables",
        "",
        "| Table | Columns | Foreign Keys | Indexes |",
        "| --- | ---: | ---: | ---: |"
    ]

    var tableDetails: [(table: TableInfo, columns: [ColumnInfo], foreignKeys: [ForeignKeyInfo], indexes: [IndexInfo])] = []

    for table in tables {
        let columns = try fetchColumns(database: database, tableName: table.name)
        let foreignKeys = try fetchForeignKeys(database: database, tableName: table.name)
        let indexes = try fetchIndexes(database: database, tableName: table.name)
        tableDetails.append((table, columns, foreignKeys, indexes))
        lines.append("| \(markdownValue(table.name)) | \(columns.count) | \(foreignKeys.count) | \(indexes.count) |")
    }

    for detail in tableDetails {
        lines.append(contentsOf: [
            "",
            "## \(detail.table.name)",
            "",
            "### Columns",
            "",
            "| Name | Type | Not Null | Default | Primary Key | Hidden |",
            "| --- | --- | --- | --- | --- | --- |"
        ])

        for column in detail.columns {
            lines.append(
                "| \(markdownValue(column.name)) | \(markdownValue(column.type)) | \(yesNo(column.isNotNull)) | \(markdownValue(column.defaultValue)) | \(column.primaryKeyPosition) | \(column.hiddenKind) |"
            )
        }

        lines.append(contentsOf: [
            "",
            "### Foreign Keys",
            ""
        ])

        if detail.foreignKeys.isEmpty {
            lines.append("No foreign keys.")
        } else {
            lines.append(contentsOf: [
                "| Id | Seq | From | Target Table | Target Column | On Update | On Delete | Match |",
                "| ---: | ---: | --- | --- | --- | --- | --- | --- |"
            ])
            for foreignKey in detail.foreignKeys {
                lines.append(
                    "| \(foreignKey.id) | \(foreignKey.sequence) | \(markdownValue(foreignKey.fromColumn)) | \(markdownValue(foreignKey.targetTable)) | \(markdownValue(foreignKey.toColumn)) | \(markdownValue(foreignKey.onUpdate)) | \(markdownValue(foreignKey.onDelete)) | \(markdownValue(foreignKey.match)) |"
                )
            }
        }

        lines.append(contentsOf: [
            "",
            "### Indexes",
            ""
        ])

        if detail.indexes.isEmpty {
            lines.append("No indexes.")
        } else {
            lines.append(contentsOf: [
                "| Name | Unique | Origin | Partial | Columns |",
                "| --- | --- | --- | --- | --- |"
            ])
            for index in detail.indexes {
                lines.append(
                    "| \(markdownValue(index.name)) | \(yesNo(index.isUnique)) | \(markdownValue(index.origin)) | \(yesNo(index.isPartial)) | \(markdownValue(index.columns.joined(separator: ", "))) |"
                )
            }
        }
    }

    lines.append("")
    return lines.joined(separator: "\n")
}

guard CommandLine.arguments.count == 3 else {
    throw DatabaseError.sqliteFailed(message: "Expected output path and temporary database path.")
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let databaseURL = URL(fileURLWithPath: CommandLine.arguments[2])

let database = try DatabaseConnection.open(url: databaseURL)
defer {
    try? database.close()
}

try database.executeScript("PRAGMA foreign_keys = ON;")
try DatabaseMigrator(migrations: DatabaseMigration.all).migrate(database: database)

let markdown = try makeMarkdown(database: database)
try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try markdown.write(to: outputURL, atomically: true, encoding: .utf8)

print(outputURL.path)
"""#

try helperSource.write(to: helperSourceURL, atomically: true, encoding: .utf8)

func runProcess(_ executableURL: URL, arguments: [String]) throws -> String {
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments

    let outputPipe = Pipe()
    let errorPipe = Pipe()
    process.standardOutput = outputPipe
    process.standardError = errorPipe

    try process.run()
    process.waitUntilExit()

    let output = String(
        data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""
    let error = String(
        data: errorPipe.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
    ) ?? ""

    guard process.terminationStatus == 0 else {
        throw ScriptFailure(
            description: """
            Команда завершилась с кодом \(process.terminationStatus):
            \(executableURL.path) \(arguments.joined(separator: " "))

            stdout:
            \(output)

            stderr:
            \(error)
            """
        )
    }

    return output
}

let compileArguments = ["swiftc", "-o", helperExecutableURL.path]
    + sourceURLs.map(\.path)
    + [helperSourceURL.path, "-lsqlite3"]

_ = try runProcess(
    URL(fileURLWithPath: "/usr/bin/xcrun"),
    arguments: compileArguments
)

let generatedOutput = try runProcess(
    helperExecutableURL,
    arguments: [
        outputURL.path,
        temporaryDatabaseURL.path
    ]
)

print("Generated SQLite schema documentation: \(generatedOutput.trimmingCharacters(in: .whitespacesAndNewlines))")

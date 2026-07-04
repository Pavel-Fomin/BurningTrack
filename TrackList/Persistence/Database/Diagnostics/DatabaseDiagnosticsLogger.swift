//
//  DatabaseDiagnosticsLogger.swift
//  TrackList
//
//  DEBUG-логгер снимков SQLite-фонотеки для Xcode console.
//
//  Created by Pavel Fomin on 04.07.2026.
//

#if DEBUG

import Foundation

// Печатает диагностический снимок SQLite без записи в пользовательские логи.
enum DatabaseDiagnosticsLogger {

    /// Читает фактическое состояние БД и выводит один человекочитаемый блок в Xcode console.
    static func logLibrarySnapshot() {
        do {
            let store = try DatabaseDiagnosticsStore()
            let snapshot = try store.librarySnapshot()
            print(message(for: snapshot))
        } catch {
            print("[DatabaseDiagnostics] Failed to read library snapshot: \(error)")
        }
    }

    /// Формирует стабильный формат лога для ручной проверки на реальном устройстве.
    static func message(for snapshot: DatabaseDiagnosticsSnapshot) -> String {
        var lines = [
            "[DatabaseDiagnostics] Library snapshot",
            "",
            "Root folders: \(snapshot.rootFoldersCount)",
            "Folders total: \(snapshot.foldersTotalCount)",
            "Library tracks total: \(snapshot.libraryTracksTotalCount)",
            "Metadata rows: \(snapshot.metadataRowsCount)",
            "Unavailable folders: \(snapshot.unavailableFoldersCount)",
            "Unavailable tracks: \(snapshot.unavailableTracksCount)",
            "",
            "By root folder:"
        ]

        if snapshot.rootFolders.isEmpty {
            lines.append("- none")
        } else {
            lines.append(
                contentsOf: snapshot.rootFolders.map {
                    "- \($0.name): \($0.tracksCount) tracks, \($0.foldersCount) folders"
                }
            )
        }

        return lines.joined(separator: "\n")
    }
}

#endif

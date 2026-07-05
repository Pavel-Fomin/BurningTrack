//
//  ImportManager.swift
//  TrackList
//
//  Импорт аудиофайлов в пользовательский треклист.
//  ВНИМАНИЕ: Это НЕ MusicLibrary (папки фонотеки).
//  Эти треки — только внутри TrackList, поэтому bookmark обязателен.
//
//  Created by Pavel Fomin on 28.04.2025.
//  Обновлено под новую архитектуру (TrackRegistry + BookmarksRegistry)
//

import Foundation
import AVFoundation

final class ImportManager {

    func importTracks(from urls: [URL], to folderId: UUID) async throws -> [UUID] {

        // Параметр оставлен для старого контракта вызова; imported-треки больше не получают fake folderId.
        _ = folderId

        var result: [UUID] = []

        for url in urls {

            // 1. Метаданные (опционально)
            let metadata = try? await RuntimeMetadataParser.parseMetadata(from: url)

            // 2. Постоянный trackId через слой идентичности
            // Для одиночного импорта используем отдельный путь identity,
            // потому что здесь нет rootFolderId + relativePath.
            let trackId = try await TrackIdentityResolver.shared.trackId(forImportedURL: url)

            // 3. Bookmark сохраняем в BookmarksRegistry
            if let bookmarkBase64 = BookmarkResolver.makeBookmarkBase64(for: url) {
                await BookmarksRegistry.shared.upsertTrackBookmark(
                    id: trackId,
                    base64: bookmarkBase64
                )
            } else {
                print("❌ Не удалось создать bookmark для файла: \(url.lastPathComponent)")
            }

            // 4. TrackRegistry сохраняет imported-трек в SQLite без фиктивной папки фонотеки.
            await TrackRegistry.shared.upsertImportedTrack(
                id: trackId,
                fileName: url.lastPathComponent,
                fileURL: url
            )

            print("📥 Импортирован: \(metadata?.title ?? url.lastPathComponent)")
            result.append(trackId)
        }

        // Финально пробрасываем возможные ошибки SQLite, накопленные во время non-throwing upsert-вызовов.
        try await TrackRegistry.shared.throwPendingPersistenceError()
        try await BookmarksRegistry.shared.throwPendingPersistenceError()

        return result
    }
}

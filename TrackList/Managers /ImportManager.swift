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

    func importTracks(from urls: [URL], to folderId: UUID) async -> [UUID] {

        var result: [UUID] = []

        for url in urls {

            // 1. Доступ к файлу
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ Нет доступа: \(url.lastPathComponent)")
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // 2. Метаданные (опционально)
            let metadata = try? await MetadataParser.parseMetadata(from: url)

            // 3. Стабильный trackId
            let trackId = UUID.v5(from: url.path)

            // 4. Bookmark сохраняем в BookmarksRegistry
            if let bookmarkData = try? url.bookmarkData() {
                await BookmarksRegistry.shared.upsertTrackBookmark(
                    id: trackId,
                    base64: bookmarkData.base64EncodedString()
                )
            }

            // 5. TrackRegistry — только метаданные
            await TrackRegistry.shared.upsertTrack(
                id: trackId,
                fileName: url.lastPathComponent,
                folderId: folderId
            )

            print("📥 Импортирован: \(metadata?.title ?? url.lastPathComponent)")
            result.append(trackId)
        }

        // Persist — один раз
        await TrackRegistry.shared.persist()
        await BookmarksRegistry.shared.persist()

        return result
    }
}

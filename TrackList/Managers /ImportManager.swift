//
//  ImportManager.swift
//  TrackList
//
//  Импорт аудиофайлов в пользовательский треклист.
//  ВНИМАНИЕ: Это НЕ MusicLibrary (папки фонотеки).
//  Эти треки — только внутри TrackList, поэтому bookmark обязателен.
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import AVFoundation

final class ImportManager {
    func importTracks(from urls: [URL], to folderId: UUID) async -> [UUID] {
        var result: [UUID] = []

        for url in urls {

            // 1. Метаданные (опционально)
            let metadata = try? await MetadataParser.parseMetadata(from: url)

            // 2. Стабильный trackId
            let trackId = UUID.v5(from: url.path)

            // 3. Bookmark сохраняем в BookmarksRegistry через общий Resolver
            if let bookmarkBase64 = BookmarkResolver.makeBookmarkBase64(for: url) {
                await BookmarksRegistry.shared.upsertTrackBookmark(
                    id: trackId,
                    base64: bookmarkBase64
                )
            } else {
                print("❌ Не удалось создать bookmark для файла: \(url.lastPathComponent)")
            }

            // 4. TrackRegistry — только метаданные
            await TrackRegistry.shared.upsertTrack(
                id: trackId,
                fileName: url.lastPathComponent,
                folderId: folderId,
                rootFolderId: folderId
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

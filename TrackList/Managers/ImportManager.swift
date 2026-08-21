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

        // Импортированные треки не получают вымышленный идентификатор папки, потому что у них нет корневого пути фонотеки.
        _ = folderId

        var result: [UUID] = []

        for url in urls {

            // 1. Метаданные (опционально)
            let metadata = try? await RuntimeMetadataParser.parseMetadata(from: url)

            // 2. Сначала готовим bookmark: без него imported identity не должна попадать в SQLite.
            guard let bookmarkBase64 = BookmarkResolver.makeBookmarkBase64(for: url) else {
                throw AppError.bookmarkCreateFailed
            }

            // 3. Строка трека, identity и bookmark фиксируются одним commit.
            // Внешний исходный файл не удаляется при ошибке, потому что приложению не принадлежит.
            let trackId = try await TrackIdentityResolver.shared.registerImportedTrack(
                forURL: url,
                bookmarkBase64: bookmarkBase64
            )

            print("📥 Импортирован: \(metadata?.title ?? url.lastPathComponent)")
            result.append(trackId)
        }

        return result
    }
}

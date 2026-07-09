//
//  FastLibraryTracksProvider.swift
//  TrackList
//
//  Быстрый provider для первичного отображения треков фонотеки.
//
//  Роль:
//  - берёт треки только из TrackRegistry;
//  - не восстанавливает bookmark;
//  - не обращается к файловой системе;
//  - не читает даты файла через resourceValues;
//  - используется для моментального показа списка.
//
//  Created by Pavel Fomin on 14.05.2026.
//

import Foundation

final class FastLibraryTracksProvider: LibraryTracksProvider {

    func tracks(for source: LibraryTrackListSource) async -> [LibraryTrack] {
        switch source {
        case .folder(let folderId):
            return await tracks(inFolder: folderId)
        case .allLibraryTracks:
            return await allLibraryTracks()
        case .collectionValue(let category, let rawValue, let artistKey):
            return await tracks(
                matching: category,
                rawValue: rawValue,
                artistKey: artistKey
            )
        }
    }

    /// Возвращает треки папки из SQLite-индекса без чтения файлов.
    private func tracks(inFolder folderId: UUID) async -> [LibraryTrack] {
        let entries = await TrackRegistry.shared.tracks(inFolder: folderId)

        return entries.compactMap { entry in
            makeLibraryTrack(from: entry)
        }
    }

    /// Возвращает все локальные треки фонотеки из SQLite-индекса без чтения файлов.
    private func allLibraryTracks() async -> [LibraryTrack] {
        let entries = await TrackRegistry.shared.allTracks()

        return entries.compactMap { entry in
            makeLibraryTrack(from: entry)
        }
    }

    /// Возвращает треки, у которых сохранённые SQLite metadata совпадают со значением коллекции.
    private func tracks(
        matching category: LibraryCollectionCategory,
        rawValue: String,
        artistKey: String?
    ) async -> [LibraryTrack] {
        let entries = await TrackRegistry.shared.allTracks()
        let metadataByTrackId = await TrackRegistry.shared.cachedMetadata(
            forTrackIds: entries.map(\.id)
        )

        return entries.compactMap { entry in
            guard let metadata = metadataByTrackId[entry.id],
                  category.matches(
                    metadata: metadata,
                    rawValue: rawValue,
                    artistKey: artistKey
                  ) else {
                return nil
            }

            return makeLibraryTrack(from: entry)
        }
    }

    /// Создаёт строку фонотеки из SQLite-записи, не восстанавливая bookmark и не проверяя файл.
    private func makeLibraryTrack(
        from entry: TrackRegistry.TrackEntry
    ) -> LibraryTrack? {
        guard let relativePath = entry.relativePath else { return nil }

        return LibraryTrack(
            id: entry.id,
            fileURL: URL(fileURLWithPath: relativePath),
            title: nil,
            artist: nil,
            duration: 0,
            addedDate: entry.fileDate,
            isAvailable: entry.isAvailable
        )
    }
}

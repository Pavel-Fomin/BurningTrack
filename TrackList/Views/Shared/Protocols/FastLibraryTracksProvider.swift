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

/// Быстро находит один трек в SQLite-реестре без обращения к файлу или bookmark.
///
/// Отдельный контракт нужен восстановлению мини-плеера: ему достаточно display-модели
/// одного сохранённого трека, пока полный playback-контекст фонотеки готовится отдельно.
/// Result применяется к MainActor-bound restoration state, поэтому provider остаётся в том же owner-е.
@MainActor
protocol FastLibraryTrackProviding {
    func track(for trackId: UUID) async -> LibraryTrack?
}

final class FastLibraryTracksProvider: LibraryTracksProvider, FastLibraryTrackProviding, Sendable {

    /// Возвращает одну display-модель из TrackRegistry без проверки доступности файла.
    ///
    /// Раннее восстановление использует только уже сохранённые данные SQLite, поэтому
    /// не открывает security-scoped resource и не задерживает интерфейс синхронизацией.
    func track(for trackId: UUID) async -> LibraryTrack? {
        guard let entry = await TrackRegistry.shared.entry(for: trackId) else {
            return nil
        }

        // Краткие metadata уже сохранены в SQLite и не требуют bookmark или чтения аудиофайла.
        let cachedMetadata = await TrackRegistry.shared.cachedMetadata(
            forTrackIds: [trackId]
        )[trackId]

        return makeLibraryTrack(
            from: entry,
            cachedMetadata: cachedMetadata
        )
    }

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
        from entry: TrackRegistry.TrackEntry,
        cachedMetadata: TrackCachedMetadata? = nil
    ) -> LibraryTrack? {
        guard let relativePath = entry.relativePath else { return nil }

        return LibraryTrack(
            id: entry.id,
            fileURL: URL(fileURLWithPath: relativePath),
            title: cachedMetadata?.title,
            artist: cachedMetadata?.artist,
            duration: cachedMetadata?.duration ?? 0,
            addedDate: entry.fileDate,
            isAvailable: entry.isAvailable
        )
    }
}

//
//  LibraryPlaybackContextLoader.swift
//  TrackList
//
//  Загружает актуальные playback-контексты фонотеки из SQLite-реестра.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

/// Описывает загрузку контекстов фонотеки без раскрытия источника данных PlayerViewModel.
@MainActor
protocol LibraryPlaybackContextLoading {
    /// Возвращает отсортированный список треков конкретной папки.
    func loadFolderContext(folderId: UUID) async throws -> [LibraryTrack]

    /// Возвращает отсортированный корневой список локальных треков фонотеки.
    func loadRootContext() async throws -> [LibraryTrack]

    /// Возвращает актуальный список треков выбранного значения коллекции.
    func loadCollectionContext(
        category: LibraryCollectionCategory,
        rawValue: String,
        artistKey: String?
    ) async throws -> [LibraryTrack]
}

/// Ошибки определения постоянного источника фонотеки.
enum LibraryPlaybackContextLoaderError: Error, Equatable {
    /// Сохранённая папка больше не существует в SQLite.
    case folderNotFound(UUID)
}

/// Строит playback-массив на основании актуальных SQLite-записей и настроек сортировки.
@MainActor
final class LibraryPlaybackContextLoader: LibraryPlaybackContextLoading {
    /// Используется тот же быстрый provider, что и первичная загрузка списка фонотеки.
    private let tracksProvider: any LibraryTracksProvider

    /// Создаёт loader с возможностью подменить provider в тестах.
    init(tracksProvider: any LibraryTracksProvider = FastLibraryTracksProvider()) {
        self.tracksProvider = tracksProvider
    }

    func loadFolderContext(folderId: UUID) async throws -> [LibraryTrack] {
        let folders = await TrackRegistry.shared.folders(ids: [folderId])
        guard folders[folderId] != nil else {
            throw LibraryPlaybackContextLoaderError.folderNotFound(folderId)
        }

        let sortMode = await TrackRegistry.shared.libraryTrackSortMode(forFolderId: folderId)
        return await loadAndSort(
            source: .folder(folderId: folderId),
            sortMode: sortMode
        )
    }

    func loadRootContext() async throws -> [LibraryTrack] {
        // Корневой экран фонотеки не хранит отдельную сортировку, поэтому используется его текущий default.
        return await loadAndSort(
            source: .allLibraryTracks,
            sortMode: .fileDateDesc
        )
    }

    func loadCollectionContext(
        category: LibraryCollectionCategory,
        rawValue: String,
        artistKey: String?
    ) async throws -> [LibraryTrack] {
        // Режим сортировки значения коллекции не является постоянной настройкой,
        // поэтому восстановление использует тот же канонический порядок, что и экран списка.
        return await loadAndSort(
            source: .collectionValue(
                category: category,
                rawValue: rawValue,
                artistKey: artistKey
            ),
            sortMode: .fileDateDesc
        )
    }

    /// Загружает список через общий provider и повторяет сортировку LibraryTracksViewModel.
    private func loadAndSort(
        source: LibraryTrackListSource,
        sortMode: LibraryTrackSortMode
    ) async -> [LibraryTrack] {
        let tracks = await tracksProvider.tracks(for: source)
        let metadata: [UUID: TrackCachedMetadata]

        if sortMode.requiresCachedMetadata {
            metadata = await TrackRegistry.shared.cachedMetadata(
                forTrackIds: tracks.map(\.trackId)
            )
        } else {
            metadata = [:]
        }

        return LibraryTrackOrdering.sort(
            tracks,
            mode: sortMode,
            cachedMetadataByTrackId: metadata
        )
    }
}

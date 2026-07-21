//
//  SearchService.swift
//  TrackList
//
//  Сервис поиска по сохранённой SQLite-фонотеке.
//  Created by Pavel Fomin on 07.07.2026.
//

import Foundation

// Ошибка восстановления папки результата поиска из сохранённой фонотеки.
enum SearchServiceError: Error {
    case missingFolderContext(trackId: UUID, fileName: String)
    case folderNotFound(trackId: UUID, fileName: String, folderId: UUID)

}

// Контракт доменного сервиса поиска.
protocol SearchServicing {
    func search(query: String) async throws -> SearchResults
}

// Выполняет поиск без чтения аудиофайлов, TagLib и runtime metadata.
final class SearchService: SearchServicing {
    private let trackRegistry: TrackRegistry
    private let trackListBadgeIndex: TrackListBadgeIndex
    private let trackListsManager: TrackListsManager
    private let trackListManager: TrackListManager

    init(
        trackRegistry: TrackRegistry = .shared,
        trackListBadgeIndex: TrackListBadgeIndex = .shared,
        trackListsManager: TrackListsManager = .shared,
        trackListManager: TrackListManager = .shared
    ) {
        self.trackRegistry = trackRegistry
        self.trackListBadgeIndex = trackListBadgeIndex
        self.trackListsManager = trackListsManager
        self.trackListManager = trackListManager
    }

    /// Ищет по уже сохранённым данным; пустой запрос всегда возвращает пустой набор.
    func search(query: String) async throws -> SearchResults {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedQuery.isEmpty == false else { return .empty }

        let results = try await librarySearchResults()

        return SearchResults(
            folders: results.folders
                .filter { Self.matches($0, query: normalizedQuery) }
                .sorted(by: Self.sortFolderResults),
            trackLists: results.trackLists
                .filter { Self.matches($0, query: normalizedQuery) }
                .sorted(by: Self.sortTrackListResults),
            tracks: results.tracks
                .filter { Self.matches($0, query: normalizedQuery) }
                .sorted(by: Self.sortTrackResults)
        )
    }

    /// Собирает поисковый каталог через существующие слои фонотеки и треклистов.
    private func librarySearchResults() async throws -> SearchResults {
        let folderEntries = await trackRegistry.allFolderEntries()
        let foldersById = folderEntries.reduce(into: [UUID: TrackRegistry.FolderEntry]()) { result, folder in
            result[folder.id] = folder
        }
        let tracks = await trackRegistry.allTracks()
            .filter { track in
                track.source == .library
            }
        let trackIds = tracks.map(\.id)
        let cachedMetadataByTrackId = await trackRegistry.cachedMetadata(forTrackIds: trackIds)
        let trackListNamesByTrackId = trackListBadgeIndex.badges(for: trackIds)
        let folderResults = folderEntries.compactMap(Self.folderResult)
        let trackListResults = try trackListSearchResults()

        try await trackRegistry.throwPendingPersistenceError()

        let trackResults = try tracks.map { track in
            let metadata = cachedMetadataByTrackId[track.id]
            let relativePath = Self.nonEmpty(track.relativePath) ?? track.fileName
            let rootFolderName = track.rootFolderId.flatMap { foldersById[$0]?.name }
            let folderTitle = try Self.folderTitle(
                for: track,
                foldersById: foldersById
            )

            return SearchTrackResult(
                id: track.id,
                fileName: track.fileName,
                fileDate: track.fileDate,
                relativePath: relativePath,
                folderId: track.folderId,
                rootFolderId: track.rootFolderId,
                folderTitle: folderTitle,
                libraryPath: Self.libraryPath(
                    rootFolderName: rootFolderName,
                    relativePath: relativePath
                ),
                title: metadata?.title,
                artist: metadata?.artist,
                duration: metadata?.duration ?? 0,
                album: metadata?.album,
                year: metadata?.year,
                label: metadata?.label,
                genre: metadata?.genre,
                comment: metadata?.comment,
                trackListNames: trackListNamesByTrackId[track.id] ?? [],
                isAvailable: track.isAvailable
            )
        }

        return SearchResults(
            folders: folderResults,
            trackLists: trackListResults,
            tracks: trackResults
        )
    }

    /// Собирает результаты треклистов через существующий manager-слой треклистов.
    private func trackListSearchResults() throws -> [SearchTrackListResult] {
        try trackListsManager.loadTrackListMetas()
            .map { meta in
                let tracks = try trackListManager.loadTracks(for: meta.id)
                let trackList = TrackList(
                    id: meta.id,
                    name: meta.name,
                    createdAt: meta.createdAt,
                    tracks: tracks
                )

                return SearchTrackListResult(trackList: trackList)
            }
    }

    /// Преобразует SQLite-папку фонотеки в результат поиска без искусственных fallback-названий.
    private static func folderResult(
        from folder: TrackRegistry.FolderEntry
    ) -> SearchFolderResult? {
        let displayName = nonEmpty(folder.name) ??
            nonEmpty((folder.relativePath as NSString).lastPathComponent)

        guard let displayName else { return nil }

        return SearchFolderResult(
            id: folder.id,
            name: displayName,
            relativePath: nonEmpty(folder.relativePath),
            isRoot: folder.isRoot
        )
    }

    /// Определяет заголовок секции по реальной папке трека в фонотеке.
    private static func folderTitle(
        for track: TrackRegistry.TrackEntry,
        foldersById: [UUID: TrackRegistry.FolderEntry]
    ) throws -> String {
        if let folderPath = relativeFolderPath(
            forTrackRelativePath: track.relativePath
        ) {
            return folderPath
        }

        if let folderId = track.folderId {
            guard let folder = foldersById[folderId] else {
                throw SearchServiceError.folderNotFound(
                    trackId: track.id,
                    fileName: track.fileName,
                    folderId: folderId
                )
            }

            if let folderPath = Self.nonEmpty(folder.relativePath) {
                return folderPath
            }

            if let folderName = Self.nonEmpty(folder.name) {
                return folderName
            }
        }

        if let rootFolderId = track.rootFolderId {
            guard let rootFolder = foldersById[rootFolderId] else {
                throw SearchServiceError.folderNotFound(
                    trackId: track.id,
                    fileName: track.fileName,
                    folderId: rootFolderId
                )
            }

            if let rootFolderName = Self.nonEmpty(rootFolder.name) {
                return rootFolderName
            }
        }

        throw SearchServiceError.missingFolderContext(
            trackId: track.id,
            fileName: track.fileName
        )
    }

    /// Возвращает папку из relativePath, если путь содержит не только имя файла.
    private static func relativeFolderPath(
        forTrackRelativePath relativePath: String?
    ) -> String? {
        guard let relativePath = nonEmpty(relativePath) else { return nil }

        let folderPath = (relativePath as NSString)
            .deletingLastPathComponent
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard folderPath.isEmpty == false,
              folderPath != "." else {
            return nil
        }

        return folderPath
    }

    /// Проверяет совпадение по полям трека без подтягивания всех треков совпавшей папки.
    private static func matches(
        _ result: SearchTrackResult,
        query: String
    ) -> Bool {
        if matches(values: result.searchableValues, query: query) {
            return true
        }

        guard isPathQuery(query) else {
            return false
        }

        return matches(values: [result.relativePath], query: query)
    }

    /// Относительный путь ищем только для запросов с разделителем пути.
    private static func isPathQuery(_ query: String) -> Bool {
        query.contains("/") || query.contains("\\")
    }

    /// Проверяет совпадение папки только по её названию.
    private static func matches(
        _ result: SearchFolderResult,
        query: String
    ) -> Bool {
        matches(values: result.searchableValues, query: query)
    }

    /// Проверяет совпадение треклиста по названию.
    private static func matches(
        _ result: SearchTrackListResult,
        query: String
    ) -> Bool {
        matches(values: result.searchableValues, query: query)
    }

    /// Проверяет совпадение значения с учётом регистра и диакритики.
    private static func matches(
        values: [String],
        query: String
    ) -> Bool {
        values.contains { value in
            value.range(
                of: query,
                options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
                locale: .current
            ) != nil
        }
    }

    /// Сортирует треки так же стабильно, как прежний SQL-запрос поиска.
    private static func sortTrackResults(
        _ lhs: SearchTrackResult,
        _ rhs: SearchTrackResult
    ) -> Bool {
        let titleComparison = lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }

        let pathComparison = lhs.relativePath.localizedCaseInsensitiveCompare(rhs.relativePath)
        if pathComparison != .orderedSame {
            return pathComparison == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Сортирует папки по отображаемому названию и сохранённому пути.
    private static func sortFolderResults(
        _ lhs: SearchFolderResult,
        _ rhs: SearchFolderResult
    ) -> Bool {
        let titleComparison = lhs.displayTitle.localizedCaseInsensitiveCompare(rhs.displayTitle)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }

        let lhsPath = lhs.relativePath ?? ""
        let rhsPath = rhs.relativePath ?? ""
        let pathComparison = lhsPath.localizedCaseInsensitiveCompare(rhsPath)
        if pathComparison != .orderedSame {
            return pathComparison == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Сортирует треклисты по названию и id.
    private static func sortTrackListResults(
        _ lhs: SearchTrackListResult,
        _ rhs: SearchTrackListResult
    ) -> Bool {
        let titleComparison = lhs.trackList.name.localizedCaseInsensitiveCompare(rhs.trackList.name)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }

        return lhs.id.uuidString < rhs.id.uuidString
    }

    /// Показывает путь внутри фонотеки с именем корневой папки, если оно сохранено.
    private static func libraryPath(
        rootFolderName: String?,
        relativePath: String
    ) -> String {
        guard let rootFolderName = nonEmpty(rootFolderName) else {
            return relativePath
        }

        return "\(rootFolderName)/\(relativePath)"
    }

    /// Убирает технически пустые строки из данных существующих SQLite-моделей.
    private static func nonEmpty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              trimmed.isEmpty == false else {
            return nil
        }

        return trimmed
    }
}

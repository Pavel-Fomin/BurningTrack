//
//  LibraryFolderViewModel.swift
//  TrackList
//
//  ViewModel для папки фонотеки: содержит секции, метаданные и имена треклистов
//
//  Created by Pavel Fomin on 08.08.2025.
//

import Foundation
import SwiftUI

@MainActor
final class LibraryFolderViewModel: ObservableObject {
    let folder: LibraryFolder
    private let allowedAudioExts: Set<String> = ["mp3","flac","wav","aiff","aac","m4a","ogg"]
    private let initialParseCount = 20   // подберём позже (20–40)
    
    @Published var trackSections: [TrackSection] = []          /// Группы треков по дате
    @Published var trackListNamesByURL: [URL: [String]] = [:]  /// Соответствие: URL → [названия треклистов, в которых есть трек]
    @Published var metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata] = [:]  /// Кеш метаданных (artist, title, duration и др.)
    @Published var isLoading: Bool = false
    @Published private(set) var didLoad: Bool = false
    @Published private(set) var didLoadTrackListNames = false
    @Published var subfolders: [LibraryFolder] = []

    func loadSubfoldersIfNeeded() {
        guard subfolders.isEmpty else { return }
        subfolders = MusicLibraryManager.shared.loadSubfolders(for: folder.url)
    }
    
    init(folder: LibraryFolder) {self.folder = folder}
    
    
// MARK: - Префетч артов с лимитом параллельных задач
    private func prefetchArtwork(urls: [URL], limit: Int = 6) {
        guard !urls.isEmpty else { return }
        Task.detached(priority: .userInitiated) {
            var active = 0
            await withTaskGroup(of: Void.self) { group in
                for u in urls {
                    while active >= limit { await Task.yield() }
                    active += 1
                    group.addTask {
                        _ = await ArtworkLoader.loadIfNeeded(current: nil, url: u)
                        active -= 1
                    }
                }
            }
        }
    }
    
    
// MARK: - Загружает треки из папки и группирует по дате
    
    func refresh() async {
        isLoading = true

        // 1) сканируем текущую папку (без рекурсии)
        let urls = scanFolderURLs(recursive: false)

        // 2) быстрые "лёгкие" модели — без AVAsset/MetadataParser
        //    только базовые поля, чтобы мгновенно показать список
        var shallow: [LibraryTrack] = []
        shallow.reserveCapacity(urls.count)

        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }

            let rv = try? url.resourceValues(forKeys: [.creationDateKey, .contentModificationDateKey])
            let addedDate = rv?.creationDate ?? rv?.contentModificationDate ?? Date()

            // Минимально корректные поля для UI/плеера
            let bookmarkData = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            let bookmarkBase64 = bookmarkData?.base64EncodedString() ?? ""
            let resolvedURL = SecurityScopedBookmarkHelper.resolveURL(from: bookmarkBase64) ?? url
            let isAvailable = FileManager.default.fileExists(atPath: resolvedURL.path)

            let titleFromFile = url.deletingPathExtension().lastPathComponent

            let imported = ImportedTrack(
                id: UUID(uuidString: url.lastPathComponent) ?? UUID(),
                fileName: url.lastPathComponent,
                filePath: url.path,
                orderPrefix: "",
                title: titleFromFile,
                artist: nil,
                album: nil,
                duration: 0,
                bookmarkBase64: bookmarkBase64
            )

            shallow.append(
                LibraryTrack(
                    url: url,
                    resolvedURL: resolvedURL,
                    isAvailable: isAvailable,
                    bookmarkBase64: bookmarkBase64,
                    title: titleFromFile,
                    artist: nil,
                    duration: 0,
                    artwork: nil,
                    addedDate: addedDate,
                    original: imported
                )
            )
        }

        // 3) публикуем список сразу — убираем фуллскрин-лоадер
        withAnimation(nil) {
            self.trackSections = Self.groupTracksByDate(shallow)
            self.isLoading = false
        }
        
        // Префетч мини-артов для первых ~2–4 экранов
        prefetchArtwork(urls: Array(self.trackSections.flatMap { $0.tracks }.prefix(20).map { $0.url }))
        
        // 4) префетч первых N треков — метаданные + мини-арт (в фоне, с нашими лимитами)
        let head = Array(urls.prefix(initialParseCount))
        Task(priority: .utility) { [weak self] in
            guard let self else { return }
            await withTaskGroup(of: Void.self) { group in
                let limit = 6
                var active = 0
                
                for u in head {
                    while active >= limit {
                        await Task.yield()
                    }
                    active += 1
                    
                    group.addTask {
                        if let meta = await TrackMetadataCacheManager.shared.loadMetadata(for: u) {
                            await MainActor.run { self.metadataByURL[u] = meta }
                        }
                        _ = await ArtworkLoader.loadIfNeeded(current: nil, url: u)
                        active -= 1
                    }
                }
            }
        }
    }
    
    
// MARK: -  Быстрый старт: парсим первые N треков, фоном — остальное
    
    func refreshFastStart(firstCount: Int) async {
        isLoading = true

        // 1) локально сканим папку (без рекурсии)
        let urls = scanFolderURLs(recursive: false)
        let head = Array(urls.prefix(firstCount))
        let tail = Array(urls.dropFirst(firstCount))

        // 2) первые N — сразу
        let firstSections: [TrackSection] = await Task.detached(priority: .userInitiated) { [head] in
            let tracks = await MusicLibraryManager.shared.generateLibraryTracks(from: head)
            return Self.groupTracksByDate(tracks)
        }.value

        withAnimation(nil) { self.trackSections = firstSections }
        self.isLoading = false

        // 2.1) Префетч мини-артов для первых ~2–4 экранов (параллельно)
        prefetchArtwork(urls: Array(self.trackSections.flatMap { $0.tracks }.prefix(20).map { $0.url }))

        // 3) хвост — в фоне, потом одним присвоением
        let restSections: [TrackSection] = await Task.detached(priority: .utility) { [tail] in
            guard !tail.isEmpty else { return [] }
            let restTracks = await MusicLibraryManager.shared.generateLibraryTracks(from: tail)
            return Self.groupTracksByDate(restTracks)
        }.value

        // склеиваем: пересчитываем из объединённого массива
        let allTracks = firstSections.flatMap { $0.tracks } + restSections.flatMap { $0.tracks }
        let grouped = Self.groupTracksByDate(allTracks)
        await MainActor.run {
            withAnimation(nil) { self.trackSections = grouped }
        }
    }
    
// MARK: - Загружает названия треклистов, в которых встречаются треки из этой папки
    
    func loadTrackListNamesByURL() {
        var result: [URL: [String]] = [:]
        let metas = TrackListManager.shared.loadTrackListMetas()
        
        for meta in metas {
            let trackList = TrackListManager.shared.getTrackListById(meta.id)
            for track in trackList.tracks {
                if !result[track.url, default: []].contains(meta.name) {
                    result[track.url, default: []].append(meta.name)
                }
            }
        }
        
        trackListNamesByURL = result
    }
    
    
// MARK: - Ленивая загрузка треков, если ещё не были загружены
    
    func loadTracksIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refreshFastStart(firstCount: 20)
    }
    
    
// MARK: - Внутренние методы
    
    /// Группирует треки по дате (используется для создания секций)
    nonisolated private static func groupTracksByDate(_ tracks: [LibraryTrack]) -> [TrackSection] {
        let calendar = Calendar.current
        let dayGroups = Dictionary(grouping: tracks) { track in
            calendar.startOfDay(for: track.addedDate)
        }
        .sorted { $0.key > $1.key } // новые даты выше

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        dateFormatter.locale = .current

        return dayGroups.map { (day, items) in
            let title: String = {
                if calendar.isDateInToday(day) { return "Сегодня" }
                if calendar.isDateInYesterday(day) { return "Вчера" }
                return dateFormatter.string(from: day)
            }()
            return TrackSection(id: ISO8601DateFormatter().string(from: day), title: title, tracks: items)
        }
    }
    
    
// MARK: - Локальный скан файлов ТОЛЬКО этой папки (по умолчанию без рекурсии)
    
    private func scanFolderURLs(recursive: Bool = false, maxDepth: Int = 1) -> [URL] {
        var result: [URL] = []

        let url = folder.url
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }

        do {
            let fm = FileManager.default
            let contents = try fm.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            var subfolders: [URL] = []

            for item in contents {
                let values = try? item.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true {
                    if recursive && maxDepth > 0 { subfolders.append(item) }
                } else {
                    let ext = item.pathExtension.lowercased()
                    if allowedAudioExts.contains(ext) {
                        result.append(item)
                    }
                }
            }

            if recursive && maxDepth > 0 {
                for sub in subfolders {
                    // контролируем глубину
                    result.append(contentsOf: scanFolderURLs(at: sub, recursive: true, depth: maxDepth - 1))
                }
            }
        } catch {
            print("❌ scanFolderURLs error:", error)
        }

        return result
    }
    

    // MARK: - Вспомогательный приватный скан для рекурсии
    
    private func scanFolderURLs(at root: URL, recursive: Bool, depth: Int) -> [URL] {
        var result: [URL] = []
        let accessed = root.startAccessingSecurityScopedResource()
        defer { if accessed { root.stopAccessingSecurityScopedResource() } }

        do {
            let fm = FileManager.default
            let contents = try fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )

            var subfolders: [URL] = []

            for item in contents {
                let values = try? item.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true {
                    if recursive && depth > 0 { subfolders.append(item) }
                } else {
                    let ext = item.pathExtension.lowercased()
                    if allowedAudioExts.contains(ext) {
                        result.append(item)
                    }
                }
            }

            if recursive && depth > 0 {
                for sub in subfolders {
                    result.append(contentsOf: scanFolderURLs(at: sub, recursive: true, depth: depth - 1))
                }
            }
        } catch {
            print("❌ scanFolderURLs(depth) error:", error)
        }

        return result
    }
    
    
// MARK: - Названия треклистов
    
    func loadTrackListNamesIfNeeded() {
        guard !didLoadTrackListNames else { return }
        didLoadTrackListNames = true
        loadTrackListNamesByURL()
    }
}

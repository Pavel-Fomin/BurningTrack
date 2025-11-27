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
import Combine

@MainActor
final class LibraryFolderViewModel: ObservableObject {
    private let debugID = UUID()
    
    let folder: LibraryFolder
    private let allowedAudioExts: Set<String> = ["mp3","flac","wav","aiff","aac","m4a","ogg"]
    private let initialParseCount = 20
    
    private var lastScannedURLs: [URL] = []
    private var tailWarmupTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Состояния
    
    @Published var pendingRevealTrackID: UUID?
    
    @Published var trackSections: [TrackSection] = []
    @Published var trackListNamesByURL: [URL: [String]] = [:]
    @Published var metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata] = [:]
    
    @Published var isLoading: Bool = false
    @Published private(set) var didLoad: Bool = false
    @Published private(set) var didLoadTrackListNames = false
    
    @Published var subfolders: [LibraryFolder] = []
    
    @Published private(set) var didStartTailWarmup = false
    
    var headCount: Int {
        let allTracks = trackSections.reduce(into: 0) { result, section in
            result += section.tracks.count
        }
        return min(initialParseCount, allTracks)
    }
    
    private var trackListsObserver: NSObjectProtocol?
    
    // MARK: - Инициализация
    
    init(folder: LibraryFolder) {
        self.folder = folder
        
        trackListsObserver = NotificationCenter.default.addObserver(
            forName: .trackListsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadTrackListNamesByURL()
            }
        }
        
        cancellables.removeAll()
    }

    
    // MARK: - Подпапки
    
    func loadSubfoldersIfNeeded() {
        guard subfolders.isEmpty else { return }
        subfolders = MusicLibraryManager.shared.loadSubfolders(for: folder.url)
    }
    
    
    // MARK: - Ленивая загрузка
    
    /// Загружает треки только один раз
    func loadTracksIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }
    
    /// Загружает названия треклистов только один раз
    func loadTrackListNamesIfNeeded() {
        guard !didLoadTrackListNames else { return }
        didLoadTrackListNames = true
        loadTrackListNamesByURL()
    }
    
    // MARK: - Быстрая загрузка треков (Fast Start)

    func refresh() async {
        await refreshFastStart(firstCount: initialParseCount)
    }

    func refreshFastStart(firstCount: Int) async {
        isLoading = true

        // 1) Сканируем папку → порядок файлов
        let urls = scanFolderURLs(recursive: false)
        lastScannedURLs = urls

        let orderMap = Dictionary(uniqueKeysWithValues: urls.enumerated().map { ($0.element, $0.offset) })

        let head = Array(urls.prefix(firstCount))
        let tail = Array(urls.dropFirst(firstCount))

        let folderId = folder.id

        // 2) Загружаем записи из акторa ДО detached
        let entries = await TrackRegistry.shared.tracks(inFolder: folderId)

        // 3) Преобразуем TrackEntry → LibraryTrack
        let allTracks: [LibraryTrack] = entries.compactMap { entry in
            guard let realURL = TrackRegistry.shared.resolvedURLSync(for: entry.id) else { return nil }
            return LibraryTrack(
                id: entry.id,
                fileURL: realURL,
                title: nil,
                artist: nil,
                duration: 0,
                addedDate: entry.updatedAt
            )
        }

        // HEAD (первые N треков)
        let firstSections: [TrackSection] =
        await Task.detached(priority: .userInitiated) { [allTracks, head, orderMap] in
            let headTracks = allTracks.filter { head.contains($0.url) }
            return Self.groupTracksByDate(headTracks, order: orderMap)
        }.value

        await MainActor.run {
            withAnimation(nil) {
                self.trackSections = firstSections
                self.isLoading = false
            }
        }

        // TAIL (всё остальное)
        let restTracks: [LibraryTrack] =
        await Task.detached(priority: .utility) { [allTracks, tail] in
            guard !tail.isEmpty else { return [] }
            return allTracks.filter { tail.contains($0.url) }
        }.value

        // Подгружаем бейджи треклистов для уже видимых треков
        await MainActor.run { self.loadTrackListNamesByURL() }

        guard !restTracks.isEmpty else { return }

        // Склеиваем HEAD + TAIL
        let allCombined = firstSections.flatMap { $0.tracks } + restTracks

        let grouped = Self.groupTracksByDate(allCombined, order: orderMap)

        await MainActor.run {
            withAnimation(nil) {
                self.trackSections = grouped
            }
        }

        // После завершения tail — обновляем бейджи ещё раз
        Task.detached { [weak self] in
            guard let self else { return }
            await MainActor.run { self.loadTrackListNamesByURL() }
        }
    }
    
    // MARK: - TrackList Badges
    
    func loadTrackListNamesByURL() {
        
        // какие URL сейчас в секциях
        var urlsInView: [URL] = []
        urlsInView.reserveCapacity(trackSections.count * 10)
        
        for section in trackSections {
            for track in section.tracks {
                urlsInView.append(track.url)
            }
        }
        
        var namesByURL: [URL: Set<String>] = [:]
        var result: [URL: [String]] = [:]
        
        // все треклисты
        let metas = TrackListsManager.shared.loadTrackListMetas()
        
        for meta in metas {
            let list = TrackListManager.shared.getTrackListById(meta.id)
            
            for t in list.tracks {
                namesByURL[t.url, default: []].insert(meta.name)
            }
        }
        
        for url in urlsInView {
            let names = namesByURL[url] ?? []
            result[url] = Array(names).sorted()
        }
        
        trackListNamesByURL = result
    }
    
    // MARK: - Metadata update
    
    func setMetadata(_ meta: TrackMetadataCacheManager.CachedMetadata, for url: URL) {
        metadataByURL[url] = meta
        loadTrackListNamesByURL()
    }
    
    // MARK: - Scan
    
    private func scanFolderURLs(recursive: Bool = false, maxDepth: Int = 1) -> [URL] {
        scanFolderURLs(at: folder.url, maxDepth: maxDepth, recursive: recursive)
    }
    
    private func scanFolderURLs(at root: URL, maxDepth: Int, recursive: Bool) -> [URL] {
        var result: [URL] = []
        
        let accessed = root.startAccessingSecurityScopedResource()
        defer { if accessed { root.stopAccessingSecurityScopedResource() } }
        
        do {
            let fm = FileManager.default
            let items = try fm.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            
            var subfolders: [URL] = []
            
            for item in items {
                let isDir = (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
                
                if isDir {
                    if recursive && maxDepth > 0 {
                        subfolders.append(item)
                    }
                } else {
                    let ext = item.pathExtension.lowercased()
                    if allowedAudioExts.contains(ext) {
                        result.append(item)
                    }
                }
            }
            
            if recursive && maxDepth > 0 {
                for sub in subfolders {
                    result.append(contentsOf: scanFolderURLs(at: sub, maxDepth: maxDepth - 1, recursive: true))
                }
            }
        } catch {
            print("❌ scanFolderURLs error:", error)
        }
        
        return result
    }
    
    // MARK: - Support
    
    nonisolated static func groupTracksByDate(
        _ tracks: [LibraryTrack],
        order: [URL:Int]? = nil
    ) -> [TrackSection] {
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: tracks) { track in
            calendar.startOfDay(for: track.addedDate)
        }
        
        let days = grouped.keys.sorted(by: >)
        
        return days.map { day in
            var items = grouped[day] ?? []
            
            items.sort { a, b in
                if let order,
                   let oa = order[a.url],
                   let ob = order[b.url],
                   oa != ob {
                    return oa < ob
                }
                if a.addedDate != b.addedDate { return a.addedDate > b.addedDate }
                return a.url.lastPathComponent < b.url.lastPathComponent
            }
            
            let title: String = {
                if calendar.isDateInToday(day) { return "Сегодня" }
                if calendar.isDateInYesterday(day) { return "Вчера" }
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .none
                return df.string(from: day)
            }()
            
            return TrackSection(
                id: ISO8601DateFormatter().string(from: day),
                title: title,
                tracks: items
            )
        }
    }
  
    
    deinit {
        cancellables.forEach { $0.cancel() }
        if let o = trackListsObserver {
            NotificationCenter.default.removeObserver(o)
        }
        print("🧹 deinit LibraryFolderViewModel:", folder.name)
    }
    
    // MARK: - Поиск трека в секциях
    
    private func findTrack(in sections: [TrackSection], matching id: UUID) -> LibraryTrack? {
        for section in sections {
            if let match = section.tracks.first(where: { $0.id == id }) {
                return match
            }
        }
        return nil
    }
}

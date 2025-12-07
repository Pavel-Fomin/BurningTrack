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
    
    // MARK: - Входные данные
    
    let folder: LibraryFolder
    
    // MARK: - Состояния
    
    @Published var pendingRevealTrackID: UUID?
    @Published var trackSections: [TrackSection] = []
    @Published var trackListNamesById: [UUID: [String]] = [:]
    @Published var metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata] = [:]
    @Published var isLoading: Bool = false
    @Published var subfolders: [LibraryFolder] = []
    
    @Published private(set) var didLoad: Bool = false
    @Published private(set) var didLoadTrackListNames = false
    @Published private(set) var displayMode: DisplayMode = .empty
    
    // MARK: - Display mode
    
    enum DisplayMode {
        case tracks
        case subfolders
        case empty
    }
    
    // MARK: - Subscriptions
    
    private var trackListsObserver: NSObjectProtocol?
    
    // MARK: - Init
    
    init(folder: LibraryFolder) {
        self.folder = folder
        updateDisplayMode()
        
        trackListsObserver = NotificationCenter.default.addObserver(
            forName: .trackListsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadTrackListNamesByURL()
            }
        }
    }
    
    deinit {
        if let o = trackListsObserver {
            NotificationCenter.default.removeObserver(o)
        }
        print("🧹 deinit LibraryFolderViewModel:", folder.name)
    }
    
    // MARK: - Подпапки
    
    func loadSubfoldersIfNeeded() {
        guard subfolders.isEmpty else { return }
        subfolders = folder.subfolders
        updateDisplayMode()
    }
    
    func updateDisplayMode() {
        if !subfolders.isEmpty {
            displayMode = .subfolders
        } else if !folder.audioFiles.isEmpty {
            displayMode = .tracks
        } else {
            displayMode = .empty
        }
    }
    
    // MARK: - Ленивая загрузка треков
    
    func loadTracksIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }
    
    func loadTrackListNamesIfNeeded() {
        guard !didLoadTrackListNames else { return }
        didLoadTrackListNames = true
        loadTrackListNamesByURL()
    }
    
    // MARK: - Refresh (основная загрузка)
    
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        let folderId = folder.url.libraryFolderId
        
        // 1. Получаем entry треков из TrackRegistry
        let entries = await TrackRegistry.shared.tracks(inFolder: folderId)
        
        // 2. Преобразуем в LibraryTrack
        var tracks: [LibraryTrack] = []
        tracks.reserveCapacity(entries.count)
        
        for entry in entries {
            if let url = await BookmarkResolver.url(forTrack: entry.id) {
                
                // Дата файла: contentModificationDate / creationDate
                var fileDate = entry.updatedAt
                if let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey]) {
                    fileDate =
                    values.contentModificationDate ??
                    values.creationDate ??
                    entry.updatedAt
                }
                
                tracks.append(
                    LibraryTrack(
                        id: entry.id,
                        fileURL: url,
                        title: nil,
                        artist: nil,
                        duration: 0,
                        addedDate: fileDate
                    )
                )
            }
        }
        
        // 3. Группируем по датам изменения файла
        let grouped = Self.groupTracksByDate(tracks)
        
        // 4. UI
        await MainActor.run {
            self.trackSections = grouped
            self.loadTrackListNamesByURL()
        }
    }
    
    // MARK: - TrackList Badges
    
    func loadTrackListNamesByURL() {
        Task { @MainActor in
            
            // Собираем все ID треков на экране
            var idsInView: [UUID] = []
            for section in trackSections {
                for track in section.tracks {
                    idsInView.append(track.id)
                }
            }
            
            var namesById: [UUID: Set<String>] = [:]
            
            // Загружаем все треклисты
            let metas = TrackListsManager.shared.loadTrackListMetas()
            
            for meta in metas {
                let list = TrackListManager.shared.getTrackListById(meta.id)
                
                for t in list.tracks {
                    namesById[t.id, default: []].insert(meta.name)
                }
            }
            
            // Формируем финальный словарь: ID → массив имён
            var result: [UUID: [String]] = [:]
            for id in idsInView {
                let names = namesById[id] ?? []
                result[id] = Array(names).sorted()
            }
            
            self.trackListNamesById = result
        }
    }
    
    // MARK: - Metadata update
    
    func setMetadata(_ meta: TrackMetadataCacheManager.CachedMetadata, for url: URL) {
        metadataByURL[url] = meta
    }
    
    // MARK: - Support. Отображение дат в формате "сегодня,вчера"
    
    nonisolated static func groupTracksByDate(_ tracks: [LibraryTrack]) -> [TrackSection] {
        let calendar = Calendar.current
        
        // Группировка треков по дню
        let grouped = Dictionary(grouping: tracks) { track in
            calendar.startOfDay(for: track.addedDate)
        }
        
        // Сортировка дней: новые сверху
        let sortedDays = grouped.keys.sorted(by: >)
        
        // Один раз создаём форматтер
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        // Формируем секции
        return sortedDays.map { day in
            let sectionTitle: String = {
                if calendar.isDateInToday(day) { return "Сегодня" }
                if calendar.isDateInYesterday(day) { return "Вчера" }
                return dateFormatter.string(from: day)
            }()
            
            let items = (grouped[day] ?? []).sorted {
                // Сортировка внутри дня:
                // сначала по дате изменения, потом по имени файла
                ($0.addedDate, $0.url.lastPathComponent)
                >
                ($1.addedDate, $1.url.lastPathComponent)
            }
            
            return TrackSection(
                id: day.ISO8601String,
                title: sectionTitle,
                tracks: items
            )
        }
    }
}

private extension Date {
    var ISO8601String: String {
        ISO8601DateFormatter().string(from: self)
    }
}

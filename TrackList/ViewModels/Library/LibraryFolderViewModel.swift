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
    let urls: [URL]                                            /// Список аудиофайлов в папке (фиксируется при инициализации)
    
    @Published var trackSections: [TrackSection] = []          /// Группы треков по дате
    @Published var trackListNamesByURL: [URL: [String]] = [:]  /// Соответствие: URL → [названия треклистов, в которых есть трек]
    @Published var metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata] = [:]  /// Кеш метаданных (artist, title, duration и др.)
    @Published var isLoading: Bool = false
    @Published private(set) var didLoad: Bool = false
    
    init(folder: LibraryFolder) {
        self.folder = folder
        self.urls = folder.audioFiles
    }
    
    /// Загружает треки из папки и группирует по дате
    func refresh() async {
        isLoading = true
        let urls = self.urls  /// локальная копия, чтобы не захватывать self в detach

        /// Тяжёлую часть вычислим в фоне
        let grouped: [TrackSection] = await Task.detached(priority: .userInitiated) { [urls] in
            let tracks = await MusicLibraryManager.shared.generateLibraryTracks(from: urls)
            return Self.groupTracksByDate(tracks)
        }.value

        /// Публикация — на MainActor (мы уже на MainActor внутри класса)
        withAnimation(nil) {
            self.trackSections = grouped
        }
        self.isLoading = false
    }
    
    /// Загружает названия треклистов, в которых встречаются треки из этой папки
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
    
    /// Ленивая загрузка треков, если ещё не были загружены
    func loadTracksIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await refresh()
    }
    
// MARK: - Внутренние методы
    
    /// Группирует треки по дате (используется для создания секций)
    nonisolated private static func groupTracksByDate(_ tracks: [LibraryTrack]) -> [TrackSection] {
        let calendar = Calendar.current
        
        let grouped = Dictionary(grouping: tracks) { track in
            let date = track.addedDate
            if calendar.isDateInToday(date) {
                return "Сегодня"
            } else if calendar.isDateInYesterday(date) {
                return "Вчера"
            } else {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .none
                formatter.locale = .current
                return formatter.string(from: date)
            }
        }
        
        return grouped
            .sorted(by: { $0.key > $1.key })
            .map { (key, value) in
                    .init(id: key, title: key, tracks: value)
            }
    }
}

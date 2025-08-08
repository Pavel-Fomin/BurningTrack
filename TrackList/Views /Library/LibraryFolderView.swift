//
//  LibraryFolderView.swift
//  TrackList
//
//  Created by Pavel Fomin on 27.06.2025.
//

import SwiftUI

struct LibraryFolderView: View {
    let folder: LibraryFolder
    let trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var trackListNamesByURL: [URL: [String]] = [:]
    @State private var metadataByURL: [URL: TrackMetadataCacheManager.CachedMetadata] = [:]
    @EnvironmentObject var sheetManager: SheetManager
    
    @State private var isLoading: Bool = false
    
    private var allVisibleTracks: [LibraryTrack] {
        trackSections.flatMap { $0.tracks }
    }
    
    
// MARK: - Вспомогательная модель секции
    
    struct TrackSection: Identifiable {
        let id: String
        let title: String
        let tracks: [LibraryTrack]
    }
    
    @State private var trackSections: [TrackSection] = []
    
    var body: some View {
        ZStack {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Загружаю треки")
                        .progressViewStyle(CircularProgressViewStyle())
                        .font(.headline)
                        .padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            } else {
                List {
                    folderSectionView()
                    trackSectionsView()
                }
                .refreshable {
                    await refresh()
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .task {
                    await loadTracksIfNeeded()
                    loadTrackListNamesByURL()
                }
            }
        }
        .navigationTitle(folder.name) // теперь заголовок всегда показывается
        .sheet(item: $sheetManager.trackToAdd) { track in
            NavigationStack {
                AddToTrackListSheet(
                    track: track,
                    onComplete: {
                        sheetManager.close()
                        loadTrackListNamesByURL()
                    }
                )
                .presentationDetents([.fraction(0.5)])
            }
        }
    }
    
    
    
// MARK: - Загрузка треков
    
    private func loadTracksIfNeeded() async {
        guard trackSections.isEmpty else { return }
        await refresh()
        
    }
    
    
// MARK: - Группировка по дате
    
    private func groupTracksByDate(_ tracks: [LibraryTrack]) -> [TrackSection] {
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
            .map { TrackSection(id: $0.key, title: $0.key, tracks: $0.value.sorted { $0.addedDate > $1.addedDate }) }
            .sorted { $0.tracks.first!.addedDate > $1.tracks.first!.addedDate }
    }
    
    
// MARK: - Секция подпапок
    
    @ViewBuilder
    private func folderSectionView() -> some View {
        if !folder.subfolders.isEmpty {
            Section {
                ForEach(folder.subfolders) { subfolder in
                    NavigationLink(
                        destination: LibraryFolderView(
                            folder: subfolder,
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel
                        )
                        
                    ) {
                        HStack(spacing: 12) {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(subfolder.name)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 4)
                    }
                    
                }
            }
        }
    }
    
    
// MARK: - Секция треков
    
    @ViewBuilder
    private func trackSectionsView() -> some View {
        ForEach(trackSections, id: \.id) { section in
            LibraryTrackSectionView(
                title: section.title,
                tracks: section.tracks,
                allTracks: allVisibleTracks,
                trackListViewModel: trackListViewModel,
                trackListNamesByURL: trackListNamesByURL,
                artworkByURL: [:],
                playerViewModel: playerViewModel,
                metadataByURL: metadataByURL
            )
        }
    }
    
    
// MARK: - Обновление списка треков
    
    @MainActor
    private func refresh() async {
        isLoading = true

        let urls = folder.audioFiles
        let libraryTracks = await MusicLibraryManager.shared.generateLibraryTracks(from: urls)
        let grouped = groupTracksByDate(libraryTracks)

        trackSections = grouped

        for track in allVisibleTracks {
            if metadataByURL[track.resolvedURL] == nil {
                Task {
                    if let metadata = await TrackMetadataCacheManager.shared.loadMetadata(for: track.resolvedURL) {
                        await MainActor.run {
                            metadataByURL[track.resolvedURL] = metadata
                        }
                    }
                }
            }
        }

        isLoading = false
    }
    
    
    @MainActor
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
}

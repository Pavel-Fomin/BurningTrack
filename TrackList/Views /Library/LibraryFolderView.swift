//
//  LibraryFolderView.swift
//  TrackList
//
//  Created by Pavel Fomin on 27.06.2025.
//

import SwiftUI

struct LibraryFolderView: View {
    let folder: LibraryFolder
    @ObservedObject var playerViewModel: PlayerViewModel
    
    
    // MARK: - Вспомогательная модель секции
    
    struct TrackSection: Identifiable {
        let id = UUID()
        let title: String
        let tracks: [LibraryTrack]
    }
    
    @State private var trackSections: [TrackSection] = []
    
    var body: some View {
        List {
            folderSectionView()
            trackSectionsView()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle(folder.name)
        .task {
            await loadTracksIfNeeded()
        }
    }
    
    
    // MARK: - Загрузка треков
    
    private func loadTracksIfNeeded() async {
        guard trackSections.isEmpty else { return }
        
        let urls = folder.audioFiles
        let libraryTracks = await MusicLibraryManager.shared.generateLibraryTracks(from: urls)
        let grouped = groupTracksByDate(libraryTracks)
        
        await MainActor.run {
            trackSections = grouped
        }
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
            .map { TrackSection(title: $0.key, tracks: $0.value.sorted { $0.addedDate > $1.addedDate }) }
            .sorted { $0.tracks.first!.addedDate > $1.tracks.first!.addedDate }
    }
    
    
    // MARK: - Секция подпапок
    
    @ViewBuilder
    private func folderSectionView() -> some View {
        if !folder.subfolders.isEmpty {
            Section {
                ForEach(folder.subfolders) { subfolder in
                    NavigationLink(destination: LibraryFolderView(folder: subfolder, playerViewModel: playerViewModel)) {
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
    
    // MARK: - Секция треков с разделителями по дате
    
    @ViewBuilder
    private func trackSectionsView() -> some View {
        ForEach(trackSections) { section in
            LibraryTrackSectionView(
                title: section.title,
                tracks: section.tracks,
                playerViewModel: playerViewModel
            )
        }
    }
    
}
   

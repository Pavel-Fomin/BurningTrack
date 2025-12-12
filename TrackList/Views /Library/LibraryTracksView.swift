//
//  LibraryTracksView.swift
//  TrackList
//
//  Отображает список треков из папки, сгруппированных по дате.
//
//  Created by Pavel Fomin on 09.08.2025.
//


import SwiftUI

struct LibraryTracksView: View {

    let folder: LibraryFolder
    let trackListViewModel: TrackListViewModel

    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var sheetManager: SheetManager
    @StateObject private var tracksViewModel: LibraryTracksViewModel
    @StateObject private var scrollSpeed = ScrollSpeedModel(thresholdPtPerSec: 1500,debounceMs: 180)

    /// Локальное состояние для скролла/подсветки
    @State private var scrollTargetID: UUID?
    @State private var revealedTrackID: UUID?
    
    
    init(
        folder: LibraryFolder,
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) {
        self.folder = folder
        self.trackListViewModel = trackListViewModel
        self._playerViewModel = ObservedObject(wrappedValue: playerViewModel)
        self._tracksViewModel = StateObject(
            wrappedValue: LibraryTracksViewModel(folderId: folder.url.libraryFolderId)
        )
    }

    // MARK: - Основное тело View

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    LibraryTrackSectionsListView(
                        sections: tracksViewModel.trackSections,
                        allTracks: tracksViewModel.trackSections.flatMap(\.tracks),
                        trackListViewModel: trackListViewModel,
                        trackListNamesById: tracksViewModel.trackListNamesById,
                        metadataByURL: tracksViewModel.metadataByURL,
                        playerViewModel: playerViewModel,
                        isScrollingFast: scrollSpeed.isFast,
                        revealedTrackID: revealedTrackID
                    )
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 88)
                }

               

                // Как только появилась цель — скроллим
                .onChange(of: scrollTargetID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                    scrollTargetID = nil
                }
            }

            // Скелетон / лоадер
            if tracksViewModel.isLoading && tracksViewModel.trackSections.isEmpty {
                VStack {
                    Spacer()
                    ProgressView("Загружаю треки")
                        .progressViewStyle(.circular)
                        .font(.headline)
                        .padding()
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).opacity(0.9))
            }
        }

        .refreshable {
            await tracksViewModel.refresh()
        }

        .task {
            await tracksViewModel.loadTracksIfNeeded()
        }
    }

    // MARK: - Вспомогательное

    /// Проверяем, есть ли трек с данным id в текущих секциях
    private func containsTrack(with id: UUID, in sections: [TrackSection]) -> Bool {
        for section in sections {
            if section.tracks.contains(where: { $0.id == id }) { return true }
        }
        return false
    }
}

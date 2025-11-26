//
//  LibraryTracksView.swift
//  TrackList
//
//  Отображает список треков из папки, сгруппированных по дате
//
//  Created by Pavel Fomin on 09.08.2025.
//

import SwiftUI

struct LibraryTracksView: View {
    let folder: LibraryFolder                                  // Папка, из которой отображаются треки
    let trackListViewModel: TrackListViewModel                 // Треклист для свайпов/добавлений
    
    @ObservedObject var coordinator: LibraryCoordinator                                               // Координатор
    @ObservedObject var playerViewModel: PlayerViewModel                                              // Плеер
    @ObservedObject var viewModel: LibraryFolderViewModel                                             // ViewModel для загрузки треков
    @EnvironmentObject var sheetManager: SheetManager                                                 // Sheet "Добавить в треклист"
    @StateObject private var scrollSpeed = ScrollSpeedModel(thresholdPtPerSec: 1500, debounceMs: 180) // Скорость скролла
    @StateObject private var navigation = NavigationCoordinator.shared
    
    
    
    // MARK: - Инициализация с передачей зависимостей и созданием viewModel
    
    
    
    // MARK: - Основное тело View
    
    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    LibraryTrackSectionsListView(
                        sections: viewModel.trackSections,
                        allTracks: viewModel.trackSections.flatMap(\.tracks),
                        trackListViewModel: trackListViewModel,
                        trackListNamesByURL: viewModel.trackListNamesByURL,
                        metadataByURL: viewModel.metadataByURL,
                        playerViewModel: playerViewModel,
                        isScrollingFast: scrollSpeed.isFast,
                        revealedTrackID: viewModel.revealedTrackID,
                        folderViewModel: viewModel,
                        coordinator: coordinator
                    )
                    
                }
                // Визуальные модификаторы
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 88)
                }
                
                // Реактивные события
                .onReceive(viewModel.$trackSections) { _ in
                    if let id = viewModel.pendingRevealTrackID {
                        viewModel.scrollToTrackIfExists(id)
                    }
                }
                
                .onReceive(viewModel.$scrollTargetID) { value in
                    guard let id = value else { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        proxy.scrollTo(id, anchor: .center)
                    }
                    viewModel.scrollTargetID = nil
                    viewModel.clearRevealState()
                }
            }
            
            // Лоадер — (при первой загрузке)
            if viewModel.isLoading && viewModel.trackSections.isEmpty {
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
        
        // Pull-to-refresh
        .refreshable {
            await viewModel.refresh()
        }
        // Звгрузка треков
        .task(id: folder.url) {
            await viewModel.loadTracksIfNeeded()
        }
        
        .navigationTitle(folder.name)
        .sheet(item: $sheetManager.trackToAdd) { track in
            NavigationStack {
                AddToTrackListSheet(track: track) {
                    sheetManager.close()
                }
                .presentationDetents([.fraction(0.5)])
            }
        }
    }
}

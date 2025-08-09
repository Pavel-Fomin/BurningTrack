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
    
    @ObservedObject var playerViewModel: PlayerViewModel       // Плеер
    @StateObject private var viewModel: LibraryFolderViewModel // ViewModel для загрузки треков
    @EnvironmentObject var sheetManager: SheetManager          // Sheet "Добавить в треклист"
    @StateObject private var scrollSpeed = ScrollSpeedModel(thresholdPtPerSec: 1500, debounceMs: 180) // Скорость скролла
    
    // MARK: - Инициализация с передачей зависимостей и созданием viewModel
    
    init(folder: LibraryFolder, trackListViewModel: TrackListViewModel, playerViewModel: PlayerViewModel) {
        self.folder = folder
        self.trackListViewModel = trackListViewModel
        self._playerViewModel = ObservedObject(wrappedValue: playerViewModel)
        self._viewModel = StateObject(wrappedValue: LibraryFolderViewModel(folder: folder))
    }
    
    // MARK: - Основное тело View
    
    var body: some View {
        ZStack {
            // Список показываем всегда
            List {
                LibraryTrackSectionsListView(
                    sections: viewModel.trackSections,
                    allTracks: viewModel.trackSections.flatMap { $0.tracks },
                    trackListViewModel: trackListViewModel,
                    trackListNamesByURL: viewModel.trackListNamesByURL,
                    metadataByURL: viewModel.metadataByURL,
                    playerViewModel: playerViewModel,
                    isScrollingFast: scrollSpeed.isFast
                )
            }
            .transaction { $0.animation = nil }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .overlay(ScrollSpeedObserver(model: scrollSpeed))
            
            // Фуллскрин-лоадер — только на самой первой загрузке
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
        
        /// pull-to-refresh — без фуллскрина
        .refreshable {
            await viewModel.refresh()
            viewModel.loadTrackListNamesIfNeeded()
        }
        
        /// триггерим первую загрузку
        .task(id: folder.url) {
            await viewModel.loadTracksIfNeeded()
            viewModel.loadTrackListNamesIfNeeded()
        }
        
        
        .navigationTitle(folder.name)
        .sheet(item: $sheetManager.trackToAdd) { track in
            NavigationStack {
                AddToTrackListSheet(track: track) { sheetManager.close() }
                    .presentationDetents([.fraction(0.5)])
            }
        }
    }
}

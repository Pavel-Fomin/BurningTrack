//
//  ContentView.swift
//  TrackList
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var trackListViewModel = TrackListViewModel()
    @StateObject var playerViewModel = PlayerViewModel()
    @State private var isImporting: Bool = false
    @State private var isShowingExportPicker = false
    @State private var showImporter = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                VStack(spacing: 0) {
                    // MARK: - Список треклистов
                    TrackListSelectorView(
                        viewModel: trackListViewModel,
                        selectedId: $trackListViewModel.currentListId,
                        onSelect: { id in
                            trackListViewModel.selectTrackList(id: id)
                        },
                        onAddFromPlus: {
                            trackListViewModel.importMode = .newList
                            showImporter = true
                        },
                        onAddFromContextMenu: {
                            trackListViewModel.importMode = .addToCurrent
                            showImporter = true
                        }
                    )                    .padding(.horizontal)
                    
                    TrackListView(
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel
                    )
                    
                    if playerViewModel.currentTrack != nil {
                        MiniPlayerView(
                            playerViewModel: playerViewModel,
                            trackListViewModel: trackListViewModel
                        )
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("TRACKLIST")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                
            }
            .sheet(isPresented: $isShowingExportPicker) {
                ExportWrapper { folderURL in
                    let id = trackListViewModel.currentListId
                    TrackListManager.shared.selectTrackList(id: id)
                    trackListViewModel.exportTracks(to: folderURL)
                }
            }
            
            // MARK: - Импорт
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                defer {
                    trackListViewModel.importMode = .none
                    print("📥 importMode сброшен после обработки")
                }

                switch result {
                case .success(let urls):
                    print("📥 fileImporter получил \(urls.count) файлов")
                    switch trackListViewModel.importMode {
                    case .newList:
                        trackListViewModel.createNewTrackListViaImport(from: urls)
                    case .addToCurrent:
                        trackListViewModel.importTracks(from: urls)
                    case .none:
                        print("⚠️ importMode = .none, ничего не делаем")
                    }
                case .failure(let error):
                    print("❌ Ошибка при импорте файлов: \(error.localizedDescription)")
                }
            }
            
            
            .onAppear {
                let startTime = Date()
                let loadTime = Date().timeIntervalSince(startTime)
                print("Приложение готово к работе за \(String(format: "%.2f", loadTime)) сек")
                trackListViewModel.refreshAllTrackLists()
                trackListViewModel.loadTracks()
            }
        }
    }
}

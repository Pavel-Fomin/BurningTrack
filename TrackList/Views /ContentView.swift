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
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Заголовок и чипсы
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
                    )
                    .padding(.top, 12)
                    .padding(.horizontal)

                    // Список треков
                    TrackListView(
                        trackListViewModel: trackListViewModel,
                        playerViewModel: playerViewModel
                    )
                    .background(Color(.systemBackground).ignoresSafeArea())
                }

                // Мини-плеер поверх
                if playerViewModel.currentTrack != nil {
                    MiniPlayerView(
                        playerViewModel: playerViewModel,
                        trackListViewModel: trackListViewModel
                    )
                    .padding(.bottom, 0)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("TRACKLIST")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.top, 12)
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

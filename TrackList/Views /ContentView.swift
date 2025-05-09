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
                        },
                        onAddFromContextMenu: {
                            trackListViewModel.importMode = .addToCurrent
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
                isPresented: Binding<Bool>(
                    get: { trackListViewModel.importMode != .none },
                    set: { newValue in
                        if !newValue {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                trackListViewModel.importMode = .none
                                print("📥 fileImporter закрыт (mode сброшен)")
                            }
                        }
                    }
                ),
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
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

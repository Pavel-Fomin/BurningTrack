//
//  ContentView.swift
//  TrackList
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var isImporting: Bool = false
    @State private var isShowingExportPicker = false
    @State private var showImporter = false
    
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemBackground) // Адаптивный фон под весь экран
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // 🔹 Хедер — отображается всегда
                    TrackListHeaderView(
                        viewModel: trackListViewModel,
                        selectedId: Binding(
                            get: { trackListViewModel.currentListId },
                            set: { trackListViewModel.currentListId = $0 }
                        ),
                        onSelect: { trackListViewModel.selectTrackList(id: $0) },
                        onAddFromPlus: {
                            trackListViewModel.importMode = .newList
                            showImporter = true
                        },
                        onAddFromContextMenu: {
                            trackListViewModel.importMode = .addToCurrent
                            showImporter = true
                        },
                        onToggleEditMode: {
                            trackListViewModel.isEditing.toggle()
                        }
                    )
                    
                    // 🔄 Если треклистов нет — заглушка
                    if trackListViewModel.trackLists.isEmpty {
                        Spacer()
                        Text("Добавьте треки")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.top, 32)
                        Spacer()
                    } else {
                        // 🟢 Здесь отобразится обычный список треков
                        TrackListView(
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel
                        )
                    }
                }
                
                // Мини-плеер поверх всего, без серого фона снизу
                if playerViewModel.currentTrack != nil {
                    MiniPlayerView(
                        playerViewModel: playerViewModel,
                        trackListViewModel: trackListViewModel
                    )
                    .padding(.bottom, 0)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $isShowingExportPicker) {
                ExportWrapper { folderURL in
                    let id = trackListViewModel.currentListId
                    if let id = trackListViewModel.currentListId {
                        TrackListManager.shared.selectTrackList(id: id)
                    }
                    
                    trackListViewModel.exportTracks(to: folderURL)
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                defer {
                    trackListViewModel.importMode = .none
                }
                
                switch result {
                case .success(let urls):
                    switch trackListViewModel.importMode {
                    case .newList:
                        trackListViewModel.createNewTrackListViaImport(from: urls)
                    case .addToCurrent:
                        trackListViewModel.importTracks(from: urls)
                    case .none:
                        break
                    }
                case .failure(let error):
                    print("❌ Ошибка при импорте файлов: \(error.localizedDescription)")
                }
            }
            .onAppear {
                let startTime = Date()
                let loadTime = Date().timeIntervalSince(startTime)
                print("Приложение готово к работе за \(String(format: "%.2f", loadTime)) сек")
                trackListViewModel.refreshtrackLists()
                trackListViewModel.loadTracks()
            }
        }
    }
}

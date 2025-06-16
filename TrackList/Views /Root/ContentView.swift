//
//  ContentView.swift
//  TrackList
//
//  Главный экран: отображает заголовок, список треков и мини-плеер
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
                // MARK: - Фон
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Хедер: кнопки, выбор плейлиста
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
                    
                    // MARK: - Список треков или заглушка
                    if trackListViewModel.trackLists.isEmpty {
                        Spacer()
                        Text("Добавьте треки")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(.top, 32)
                        Spacer()
                    } else {
                        TrackListView(
                            trackListViewModel: trackListViewModel,
                            playerViewModel: playerViewModel
                        )
                    }
                }
                
                // MARK: - Мини-плеер
                if playerViewModel.currentTrack != nil {
                    MiniPlayerView(
                        playerViewModel: playerViewModel,
                        trackListViewModel: trackListViewModel
                    )
                    .padding(.bottom, 0)
                }
            }

            // MARK: - Bottom Sheet: экспорт
            .sheet(isPresented: $isShowingExportPicker) {
                ExportWrapper { folderURL in
                    if let id = trackListViewModel.currentListId {
                        TrackListManager.shared.selectTrackList(id: id)
                    }
                    trackListViewModel.exportTracks(to: folderURL)
                }
            }

            // MARK: - FileImporter: импорт треков
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                Task {
                    switch result {
                    case .success(let urls):
                        switch trackListViewModel.importMode {
                        case .newList:
                            await trackListViewModel.createNewTrackListViaImport(from: urls)
                        case .addToCurrent:
                            await trackListViewModel.importTracks(from: urls)
                        case .none:
                            break
                        }

                    case .failure(let error):
                        print("❌ Ошибка при импорте файлов: \(error.localizedDescription)")
                    }

                    // Завершение импорта
                    trackListViewModel.importMode = .none
                }
            }

            // MARK: - Инициализация при старте
            .onAppear {
                let startTime = Date()
                let loadTime = Date().timeIntervalSince(startTime)
                print("Приложение готово к работе за \(String(format: "%.2f", loadTime)) сек")
                trackListViewModel.refreshtrackLists()
                trackListViewModel.loadTracks()
            }

            // MARK: - Навигация
            .navigationBarHidden(true)
        }
    }
}

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
    
    @ObservedObject var coordinator: LibraryCoordinator
    @ObservedObject var playerViewModel: PlayerViewModel       // Плеер
    @ObservedObject var viewModel: LibraryFolderViewModel // ViewModel для загрузки треков
    @EnvironmentObject var sheetManager: SheetManager          // Sheet "Добавить в треклист"
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
                        allTracks: viewModel.trackSections.flatMap { $0.tracks },
                        trackListViewModel: trackListViewModel,
                        trackListNamesByURL: viewModel.trackListNamesByURL,
                        metadataByURL: viewModel.metadataByURL,
                        playerViewModel: playerViewModel,
                        isScrollingFast: scrollSpeed.isFast,
                        revealedTrackID: viewModel.revealedTrackID,
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
                   .onChange(of: viewModel.trackSections) { _, _ in
                       guard let url = viewModel.pendingRevealTrackURL else { return }
                       print("🧭 [TracksView] sections changed → try reveal:", url.lastPathComponent)
                       viewModel.scrollToTrackIfExists(url)
                   }
                   .onReceive(viewModel.$scrollTargetID) { value in
                       guard let id = value else { return }
                       print("📜 Получена команда прокрутки → \(id.uuidString)")
                       withAnimation(.easeInOut(duration: 0.35)) {
                           proxy.scrollTo(id, anchor: .center)
                       }
                       viewModel.scrollTargetID = nil
                       viewModel.clearRevealState()
                   }

                   .task(id: viewModel.pendingRevealTrackURL) {
                       if let url = viewModel.pendingRevealTrackURL {
                           print("🧭 [TracksView] Task triggered scroll for:", url.lastPathComponent)
                           viewModel.scrollToTrackIfExists(url)
                       }
                   }
               }
            
            // Лоадер — только при первой загрузке
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
            viewModel.loadTrackListNamesIfNeeded()
        }

        // Первая загрузка
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

            private func actions(for context: TrackContext) -> [TrackAction] {
                switch context {
                case .library: return [.showInLibrary, .moveToFolder, .showInfo]
                case .tracklist: return [.showInLibrary, .moveToFolder, .showInfo]
                case .player: return [.moveToFolder, .showInfo]
                }
            }
        }

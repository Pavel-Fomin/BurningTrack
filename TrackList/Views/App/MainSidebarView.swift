//
//  MainSidebarView.swift
//  TrackList
//
//  Двухколоночная корневая навигация для regular horizontal size class.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import SwiftUI

/// Отображает боковую панель и detail-область iPad без создания второго набора экранов.
struct MainSidebarView: View {

    // MARK: - Зависимости

    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel
    @ObservedObject var trackListsViewModel: TrackListsViewModel
    @ObservedObject var navigationViewModel: MainNavigationViewModel
    @Binding var isSearchActive: Bool

    /// Фабрика направляет lifecycle master-flow треклистов через существующий action layer.
    private let trackListsActionHandlerFactory = TrackListsActionHandlerFactory()

    // MARK: - Представление

    /// Высокий MiniPlayer скрывается только при активном системном поиске в detail-области.
    private var showsMiniPlayer: Bool {
        navigationViewModel.activeTab != .search || isSearchActive == false
    }

    /// Detail-экраны получают тот же резерв нижней области, что и в compact-компоновке.
    private var globalBottomScrollReserve: CGFloat {
        showsMiniPlayer ? GlobalBottomGeometry.miniPlayerScrollReserve : 0
    }

    /// Обработчик сохраняет View свободным от доступа к данным треклистов.
    private var trackListsActionHandler: TrackListsActionHandler {
        trackListsActionHandlerFactory.make(
            viewModel: trackListsViewModel
        )
    }

    // MARK: - Интерфейс

    var body: some View {
        NavigationSplitView {
            List(selection: navigationViewModel.sidebarSelectionBinding) {
                Section {
                    NavigationLink(value: MainSidebarSelection.player) {
                        Label("Player", systemImage: "waveform")
                    }

                    NavigationLink(value: MainSidebarSelection.library) {
                        Label("Library", systemImage: "play.square.stack")
                    }

                    NavigationLink(value: MainSidebarSelection.search) {
                        Label("Search", systemImage: "magnifyingglass")
                    }

                    NavigationLink(value: MainSidebarSelection.settings) {
                        Label("Settings", systemImage: "gear")
                    }
                }

                Section("Tracklists") {
                    NavigationLink(value: MainSidebarSelection.allTrackLists) {
                        Label("All Tracklists", systemImage: "list.star")
                    }

                    ForEach(trackListsViewModel.trackLists) { trackList in
                        NavigationLink(value: MainSidebarSelection.trackList(trackList.id)) {
                            Text(trackList.name)
                        }
                    }
                }
            }
            .navigationTitle("TrackList")
            .onAppear {
                trackListsActionHandler.handle(.onAppear)
            }
        } detail: {
            detailContent
                // Один владелец глобальных панелей находится только в detail-области iPad.
                .globalBottomPanelsHost(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    showsMiniPlayer: showsMiniPlayer
                )
                // Экраны detail-области используют общий резерв, не влияя на боковую панель.
                .environment(
                    \.globalBottomScrollReserve,
                    globalBottomScrollReserve
                )
                .animation(
                    .easeOut(duration: 0.25),
                    value: showsMiniPlayer
                )
        }
        .navigationSplitViewStyle(.balanced)
    }

    // MARK: - Правая область

    /// Строит существующий экран выбранного раздела без переноса его бизнес-логики в iPad-контейнер.
    @ViewBuilder
    private var detailContent: some View {
        switch navigationViewModel.sidebarSelection {
        case .player:
            PlayerScreen(
                playerViewModel: playerViewModel,
                exportProgressViewModel: exportProgressViewModel
            )
        case .library:
            LibraryScreen(
                playerViewModel: playerViewModel,
                exportProgressViewModel: exportProgressViewModel
            )
        case .search:
            SearchScreen(
                playerViewModel: playerViewModel,
                isSearchActive: $isSearchActive
            )
        case .settings:
            SettingsScreen(
                playerViewModel: playerViewModel
            )
        case .allTrackLists:
            TrackListsScreen(
                trackListsViewModel: trackListsViewModel,
                playerViewModel: playerViewModel,
                exportProgressViewModel: exportProgressViewModel
            )
        case .trackList(let id):
            if let trackList = trackListsViewModel.trackList(for: id) {
                TrackListScreen(
                    trackList: trackList,
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel
                )
            } else {
                ContentUnavailableView(
                    "Tracklist Not Found",
                    systemImage: "music.note.list"
                )
            }
        }
    }
}

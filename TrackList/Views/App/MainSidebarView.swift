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
    /// Неизменяемый feature graph передаёт MiniPlayer в единственную detail-область iPad.
    let miniPlayerFeature: MiniPlayerFeature
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel
    /// Единый обработчик «Избранного» передаётся в detail-сценарии без глобального доступа из View.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    @ObservedObject var trackListsViewModel: TrackListsViewModel
    @ObservedObject var navigationViewModel: MainNavigationViewModel
    /// Готовая фабрика экранного flow плеера.
    let playerScreenViewModelFactory: PlayerScreenViewModelFactory
    /// Готовые фабрики feature фонотеки.
    let libraryFeatureDependencies: LibraryFeatureDependencies
    /// Готовая фабрика feature Search.
    let searchFeatureFactory: SearchFeatureFactory
    /// Готовая factory feature настроек.
    let settingsFeatureFactory: SettingsFeatureFactory
    /// Готовая factory detail-flow одного треклиста.
    let trackListFeatureFactory: TrackListFeatureFactory
    /// Единый ActionHandler master-flow треклистов.
    let trackListsActionHandler: TrackListsActionHandler
    /// Единый координатор межэкранной навигации.
    let navigationCoordinator: NavigationCoordinator
    @Binding var isSearchActive: Bool

    // MARK: - Представление

    /// Высокий MiniPlayer скрывается только при активном системном поиске в detail-области.
    private var showsMiniPlayer: Bool {
        navigationViewModel.activeTab != .search || isSearchActive == false
    }

    /// Detail-экраны получают тот же резерв нижней области, что и в compact-компоновке.
    private var globalBottomScrollReserve: CGFloat {
        showsMiniPlayer ? GlobalBottomGeometry.miniPlayerScrollReserve : 0
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
                            Text(
                                TrackListPresentationText.title(
                                    for: trackList.kind,
                                    storedName: trackList.name
                                )
                            )
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
                    miniPlayerFeature: miniPlayerFeature,
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
                favoriteTrackActionHandler: favoriteTrackActionHandler,
                viewModelFactory: playerScreenViewModelFactory
            )
        case .library:
            LibraryScreenContainer(
                favoriteTrackActionHandler: favoriteTrackActionHandler,
                dependencies: libraryFeatureDependencies
            )
        case .search:
            SearchContainer(
                featureFactory: searchFeatureFactory,
                isSearchActive: $isSearchActive
            )
        case .settings:
            SettingsScreen(factory: settingsFeatureFactory)
        case .allTrackLists:
            TrackListsScreen(
                trackListsViewModel: trackListsViewModel,
                actionHandler: trackListsActionHandler,
                navigationCoordinator: navigationCoordinator,
                trackListFeatureFactory: trackListFeatureFactory
            )
        case .trackList(let id):
            if trackListsViewModel.trackList(for: id) != nil {
                trackListFeatureFactory.makeContainer(trackListId: id)
            } else {
                ContentUnavailableView(
                    "Tracklist Not Found",
                    systemImage: "music.note.list"
                )
            }
        }
    }
}

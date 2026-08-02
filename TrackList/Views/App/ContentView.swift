//
//  ContentView.swift
//  TrackList
//
//  Корневой контейнер приложения.
//  - выбирает compact- или regular-компоновку корневой навигации,
//  - поверх показывает тосты и шиты,
//  - владеет ViewModel навигации и получает общую ViewModel треклистов от TrackListApp.
//
//  Навигация:
//  — основные разделы: MainNavigationViewModel и ScenePhaseHandler
//  — маршрутизация фонотеки: NavigationCoordinator, переданный Composition Root
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI

struct ContentView: View {

    @ObservedObject var playerViewModel: PlayerViewModel
    /// Published-состояние «Избранного» передаётся в глобальные sheet-сценарии.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Проверяет занятость файла в глобальных файловых sheet-сценариях.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Освобождает текущий файл через согласованное playback-состояние.
    let playbackFileReleaser: any CurrentPlaybackFileReleasing
    /// Единый обработчик «Избранного» передаётся в корневые feature-контейнеры.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Готовый app-level обработчик переименования передаётся в sheet выбора треков.
    let renameActionHandler: TrackFileRenameActionHandler
    /// Единая ViewModel master-flow треклистов, которой владеет TrackListApp.
    @ObservedObject var trackListsViewModel: TrackListsViewModel
    /// Единая ViewModel корневой навигации, которой владеет TrackListApp.
    @ObservedObject var navigationViewModel: MainNavigationViewModel
    /// Единое presentation-состояние sheet, переданное TrackListApp.
    let sheetManager: SheetManager
    /// Единый презентер Toast, переданный TrackListApp.
    let toastManager: ToastManager
    /// Единый координатор межэкранной навигации, переданный TrackListApp.
    let navigationCoordinator: NavigationCoordinator
    /// Готовая фабрика экранного flow плеера.
    let playerScreenViewModelFactory: PlayerScreenViewModelFactory
    /// Готовые фабрики feature фонотеки.
    let libraryFeatureDependencies: LibraryFeatureDependencies
    /// Готовая фабрика ViewModel поиска.
    let searchViewModelFactory: SearchViewModelFactory
    /// Готовые фабрики detail-flow одного треклиста.
    let trackListFeatureDependencies: TrackListFeatureDependencies
    /// Единый ActionHandler master-flow треклистов.
    let trackListsActionHandler: TrackListsActionHandler

    /// Единое состояние экспорта передаётся в корневой контейнер вкладок.
    @EnvironmentObject private var exportProgressViewModel: ExportProgressViewModel

    /// Размерный класс определяет единственный активный корневой контейнер приложения.
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Активность системного поиска влияет только на видимость глобального MiniPlayer.
    @State private var isSearchActive = false

    // MARK: - Интерфейс
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                MainSidebarView(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    favoriteTrackActionHandler: favoriteTrackActionHandler,
                    trackListsViewModel: trackListsViewModel,
                    navigationViewModel: navigationViewModel,
                    playerScreenViewModelFactory: playerScreenViewModelFactory,
                    libraryFeatureDependencies: libraryFeatureDependencies,
                    searchViewModelFactory: searchViewModelFactory,
                    trackListFeatureDependencies: trackListFeatureDependencies,
                    trackListsActionHandler: trackListsActionHandler,
                    navigationCoordinator: navigationCoordinator,
                    isSearchActive: $isSearchActive
                )
            } else {
                MainTabView(
                    playerViewModel: playerViewModel,
                    exportProgressViewModel: exportProgressViewModel,
                    favoriteTrackActionHandler: favoriteTrackActionHandler,
                    trackListsViewModel: trackListsViewModel,
                    navigationViewModel: navigationViewModel,
                    playerScreenViewModelFactory: playerScreenViewModelFactory,
                    libraryFeatureDependencies: libraryFeatureDependencies,
                    searchViewModelFactory: searchViewModelFactory,
                    trackListFeatureDependencies: trackListFeatureDependencies,
                    trackListsActionHandler: trackListsActionHandler,
                    navigationCoordinator: navigationCoordinator,
                    isSearchActive: $isSearchActive
                )
            }
        }
        .sheetHost(
            sheetManager: sheetManager,
            toastManager: toastManager,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            fileBusyChecker: fileBusyChecker,
            playbackFileReleaser: playbackFileReleaser,
            renameActionHandler: renameActionHandler
        )
        .toastHost(toastManager: toastManager)
    }
}

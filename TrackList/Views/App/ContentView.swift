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
    /// Неизменяемый feature graph MiniPlayer передаётся от composition root в обе корневые компоновки.
    let miniPlayerFeature: MiniPlayerFeature
    /// Проверяет занятость файла в глобальных файловых sheet-сценариях.
    let fileBusyChecker: any TrackFileBusyChecking
    /// Освобождает текущий файл через согласованное playback-состояние.
    let playbackFileReleaser: any CurrentPlaybackFileReleasing
    /// Единый обработчик «Избранного» передаётся в корневые feature-контейнеры.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
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
    /// Готовая фабрика feature Search.
    let searchFeatureFactory: SearchFeatureFactory
    /// Готовая factory feature настроек.
    let settingsFeatureFactory: SettingsFeatureFactory
    /// Готовые фабрики detail-flow одного треклиста.
    let trackListFeatureDependencies: TrackListFeatureDependencies
    /// Единый ActionHandler master-flow треклистов.
    let trackListsActionHandler: TrackListsActionHandler
    /// Готовая factory связанного flow создания и выбора треклиста.
    let createTrackListFlowFactory: CreateTrackListFlowFactory
    /// Готовая factory feature-flow переименования треклиста.
    let renameTrackListFeatureFactory: RenameTrackListFeatureFactory
    /// Готовая factory feature-flow добавления треков в треклист.
    let addToTrackListFeatureFactory: AddToTrackListFeatureFactory
    /// Готовая factory feature-flow сохранения очереди плеера в треклист.
    let saveTrackListFeatureFactory: SaveTrackListFeatureFactory
    /// Готовая factory feature-flow ручного переименования файла трека.
    let renameTrackFileFeatureFactory: RenameTrackFileFeatureFactory
    /// Готовая factory feature-flow просмотра и редактирования одного трека.
    let trackDetailFeatureFactory: TrackDetailFeatureFactory
    /// Готовая factory feature-flow выбора папки и файловой операции.
    let moveToFolderFeatureFactory: MoveToFolderFeatureFactory
    /// Готовая factory feature-local массового редактирования тегов.
    let batchTagEditFeatureFactory: BatchTagEditFeatureFactory
    /// Готовая factory feature-local массового переименования файлов.
    let batchFilenameRenameFeatureFactory: BatchFilenameRenameFeatureFactory

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
                    miniPlayerFeature: miniPlayerFeature,
                    exportProgressViewModel: exportProgressViewModel,
                    favoriteTrackActionHandler: favoriteTrackActionHandler,
                    trackListsViewModel: trackListsViewModel,
                    navigationViewModel: navigationViewModel,
                    playerScreenViewModelFactory: playerScreenViewModelFactory,
                    libraryFeatureDependencies: libraryFeatureDependencies,
                    searchFeatureFactory: searchFeatureFactory,
                    settingsFeatureFactory: settingsFeatureFactory,
                    trackListFeatureDependencies: trackListFeatureDependencies,
                    trackListsActionHandler: trackListsActionHandler,
                    navigationCoordinator: navigationCoordinator,
                    isSearchActive: $isSearchActive
                )
            } else {
                MainTabView(
                    playerViewModel: playerViewModel,
                    miniPlayerFeature: miniPlayerFeature,
                    exportProgressViewModel: exportProgressViewModel,
                    favoriteTrackActionHandler: favoriteTrackActionHandler,
                    trackListsViewModel: trackListsViewModel,
                    navigationViewModel: navigationViewModel,
                    playerScreenViewModelFactory: playerScreenViewModelFactory,
                    libraryFeatureDependencies: libraryFeatureDependencies,
                    searchFeatureFactory: searchFeatureFactory,
                    settingsFeatureFactory: settingsFeatureFactory,
                    trackListFeatureDependencies: trackListFeatureDependencies,
                    trackListsActionHandler: trackListsActionHandler,
                    navigationCoordinator: navigationCoordinator,
                    isSearchActive: $isSearchActive
                )
            }
        }
        .sheetHost(
            sheetManager: sheetManager,
            fileBusyChecker: fileBusyChecker,
            moveToFolderFeatureFactory: moveToFolderFeatureFactory,
            createTrackListFlowFactory: createTrackListFlowFactory,
            renameTrackListFeatureFactory: renameTrackListFeatureFactory,
            addToTrackListFeatureFactory: addToTrackListFeatureFactory,
            saveTrackListFeatureFactory: saveTrackListFeatureFactory,
            renameTrackFileFeatureFactory: renameTrackFileFeatureFactory,
            trackDetailFeatureFactory: trackDetailFeatureFactory,
            batchTagEditFeatureFactory: batchTagEditFeatureFactory,
            batchFilenameRenameFeatureFactory: batchFilenameRenameFeatureFactory
        )
        .toastHost(toastManager: toastManager)
    }
}

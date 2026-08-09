//
//  LibraryFeatureDependencies.swift
//  TrackList
//
//  Подготовленные фабрики корневого feature фонотеки.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Передаёт LibraryScreen только фабрики его собственного feature.
/// Тип не раскрывает глобальный граф зависимостей и не выполняет сценарии.
@MainActor
struct LibraryFeatureDependencies {

    /// Собирает ViewModel навигационного контейнера фонотеки.
    let screenViewModelFactory: LibraryScreenViewModelFactory
    /// Собирает ViewModel корня фонотеки.
    let masterViewModelFactory: LibraryMasterViewModelFactory
    /// Собирает ActionHandler корневых действий фонотеки.
    let masterActionHandlerFactory: LibraryMasterActionHandlerFactory
    /// Собирает ActionHandler экспорта общего списка треков.
    let allTracksActionHandlerFactory: LibraryAllTracksActionHandlerFactory
    /// Собирает ActionHandler экспорта значения коллекции.
    let collectionTracksActionHandlerFactory: LibraryCollectionTracksActionHandlerFactory
    /// Собирает ActionHandler раздела купленных iTunes-треков.
    let purchasedITunesActionHandlerFactory: PurchasedITunesMusicActionHandlerFactory
    /// Собирает ViewModel экрана папки фонотеки.
    let folderViewModelFactory: LibraryFolderViewModelFactory
    /// Собирает screen-local объекты и View экрана треков папки.
    let tracksScreenFactory: LibraryTracksScreenFactory
    /// Предоставляет реактивное playback-состояние экранам фонотеки.
    let playbackStateProvider: any PlaybackStateProviding
    /// Выполняет playback-команды строк и подтверждённого открепления папки.
    let playbackController: any TrackPlaybackControlling
    /// Предоставляет подтверждённое состояние «Избранного» строкам фонотеки.
    let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    /// Выполняет общий flow переименования файлов без создания handler-а во View.
    let trackFileRenameActionHandler: TrackFileRenameActionHandler
    /// Передаёт строкам iTunes явные sheet- и command-зависимости.
    let purchasedITunesTrackActionDependencies: PurchasedITunesTrackActionDependencies
}

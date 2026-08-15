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

    /// Собирает устойчивый корневой graph фонотеки.
    let screenStoreFactory: LibraryScreenStoreFactory
    /// Собирает изолированный graph значений музыкальной коллекции.
    let collectionValuesFeatureFactory: LibraryCollectionValuesFeatureFactory
    /// Собирает изолированный graph раздела купленных iTunes-треков.
    let purchasedITunesFeatureFactory: PurchasedITunesFeatureFactory
    /// Собирает ViewModel экрана папки фонотеки.
    let folderViewModelFactory: LibraryFolderViewModelFactory
    /// Собирает screen-local объекты и View экрана треков папки.
    let tracksScreenFactory: LibraryTracksScreenFactory
}

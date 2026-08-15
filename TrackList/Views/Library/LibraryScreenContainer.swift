//
//  LibraryScreenContainer.swift
//  TrackList
//
//  Удерживает корневой graph feature фонотеки.
//
//  Created by Pavel Fomin on 14.08.2026.
//

import SwiftUI

/// Создаёт LibraryScreenStore через StateObject и не позволяет LibraryScreen собирать production graph.
struct LibraryScreenContainer: View {
    /// Единый обработчик «Избранного» передаётся в строки всех источников фонотеки.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Фабрики дочерних feature фонотеки.
    let dependencies: LibraryFeatureDependencies

    /// Root store не пересоздаётся при повторной отрисовке parent View.
    @StateObject private var screenStore: LibraryScreenStore

    init(
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        dependencies: LibraryFeatureDependencies
    ) {
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.dependencies = dependencies
        self._screenStore = StateObject(
            wrappedValue: dependencies.screenStoreFactory.make()
        )
    }

    var body: some View {
        LibraryScreen(
            favoriteTrackActionHandler: favoriteTrackActionHandler,
            dependencies: dependencies,
            screenStore: screenStore
        )
    }
}

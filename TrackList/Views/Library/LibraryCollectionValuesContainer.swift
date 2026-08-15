//
//  LibraryCollectionValuesContainer.swift
//  TrackList
//
//  Удерживает graph одного экрана значений музыкальной коллекции.
//
//  Created by Pavel Fomin on 14.08.2026.
//

import SwiftUI

/// Создаёт screen-local graph через StateObject и передаёт View только готовые объекты.
struct LibraryCollectionValuesContainer: View {
    /// Выбранная категория фиксирует identity destination.
    let category: LibraryCollectionCategory
    /// Родитель остаётся владельцем typed navigation к списку треков.
    let onValueSelected: (LibraryCollectionValue) -> Void

    /// Store создаётся один раз на identity категории.
    @StateObject private var screenStore: LibraryCollectionValuesScreenStore

    init(
        factory: LibraryCollectionValuesFeatureFactory,
        category: LibraryCollectionCategory,
        onValueSelected: @escaping (LibraryCollectionValue) -> Void
    ) {
        self.category = category
        self.onValueSelected = onValueSelected
        self._screenStore = StateObject(
            wrappedValue: factory.makeScreenStore(category: category)
        )
    }

    var body: some View {
        LibraryCollectionValuesView(
            viewModel: screenStore.viewModel,
            runtimeController: screenStore.runtimeController,
            playbackStateProvider: screenStore.playbackStateProvider,
            onValueSelected: onValueSelected
        )
    }
}

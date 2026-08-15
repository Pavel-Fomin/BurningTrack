//
//  TrackListContainer.swift
//  TrackList
//
//  Создаёт и удерживает graph detail destination одного треклиста.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import SwiftUI

/// Создаёт screen-local graph через StateObject и передаёт View только готовые объекты.
struct TrackListContainer: View {
    /// Стабильная identity detail destination без snapshot из master-списка.
    let trackListId: UUID
    /// Store создаётся один раз на identity detail route.
    @StateObject private var screenStore: TrackListScreenStore

    init(
        factory: TrackListFeatureFactory,
        trackListId: UUID
    ) {
        self.trackListId = trackListId
        self._screenStore = StateObject(
            wrappedValue: factory.makeScreenStore(trackListId: trackListId)
        )
    }

    var body: some View {
        TrackListScreen(
            viewModel: screenStore.viewModel,
            actionHandler: screenStore.actionHandler
        )
    }
}

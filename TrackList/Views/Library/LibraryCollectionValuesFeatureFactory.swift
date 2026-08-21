//
//  LibraryCollectionValuesFeatureFactory.swift
//  TrackList
//
//  Собирает feature значений музыкальной коллекции.
//
//  Created by Pavel Fomin on 14.08.2026.
//

import SwiftUI

/// Создаёт стабильный graph значений коллекции вне LibraryScreen и SwiftUI View.
@MainActor
struct LibraryCollectionValuesFeatureFactory {
    /// SQLite-реестр получает provider через явную composition-зависимость.
    private let trackRegistry: TrackRegistry
    /// Состояние плеера требуется только для реактивной album-подсветки.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Runtime dependencies поступают из Composition Root, а не разрешаются в destination.
    private let runtimeSnapshotStore: any TrackRuntimeSnapshotStoring
    private let runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding

    init(
        trackRegistry: TrackRegistry,
        playbackStateProvider: any PlaybackStateProviding,
        runtimeSnapshotStore: any TrackRuntimeSnapshotStoring,
        runtimeSnapshotBuilder: any TrackRuntimeSnapshotBuilding
    ) {
        self.trackRegistry = trackRegistry
        self.playbackStateProvider = playbackStateProvider
        self.runtimeSnapshotStore = runtimeSnapshotStore
        self.runtimeSnapshotBuilder = runtimeSnapshotBuilder
    }

    /// Возвращает контейнер одного destination с устойчивой identity категории.
    func makeContainer(
        category: LibraryCollectionCategory,
        onValueSelected: @escaping (LibraryCollectionValue) -> Void
    ) -> LibraryCollectionValuesContainer {
        LibraryCollectionValuesContainer(
            factory: self,
            category: category,
            onValueSelected: onValueSelected
        )
    }

    /// Собирает ViewModel, ActionHandler и runtime controller ровно один раз для destination.
    func makeScreenStore(
        category: LibraryCollectionCategory
    ) -> LibraryCollectionValuesScreenStore {
        let viewModel = LibraryCollectionValuesViewModel(
            category: category,
            provider: DefaultLibraryCollectionValuesProvider(
                trackRegistry: trackRegistry
            )
        )
        let actionHandler = LibraryCollectionValuesActionHandler(output: viewModel)
        viewModel.configure(actionHandler: actionHandler)

        return LibraryCollectionValuesScreenStore(
            viewModel: viewModel,
            actionHandler: actionHandler,
            runtimeController: LibraryTrackRuntimeController(
                runtimeSnapshotStore: runtimeSnapshotStore,
                runtimeSnapshotBuilder: runtimeSnapshotBuilder
            ),
            playbackStateProvider: playbackStateProvider
        )
    }
}

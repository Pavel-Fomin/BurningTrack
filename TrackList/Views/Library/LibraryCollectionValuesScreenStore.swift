//
//  LibraryCollectionValuesScreenStore.swift
//  TrackList
//
//  Удерживает graph экрана значений музыкальной коллекции.
//
//  Created by Pavel Fomin on 14.08.2026.
//

import Combine

/// Хранит объекты одного destination, чтобы повторный body не создавал handler или runtime controller.
@MainActor
final class LibraryCollectionValuesScreenStore: ObservableObject {
    /// ViewModel владеет готовым screen-state значений.
    let viewModel: LibraryCollectionValuesViewModel
    /// Handler принимает typed actions View.
    let actionHandler: LibraryCollectionValuesActionHandler
    /// Контроллер runtime snapshot-ов нужен только album-строкам.
    let runtimeController: LibraryTrackRuntimeController
    /// Реактивный provider подсветки текущего альбома.
    let playbackStateProvider: any PlaybackStateProviding

    init(
        viewModel: LibraryCollectionValuesViewModel,
        actionHandler: LibraryCollectionValuesActionHandler,
        runtimeController: LibraryTrackRuntimeController,
        playbackStateProvider: any PlaybackStateProviding
    ) {
        self.viewModel = viewModel
        self.actionHandler = actionHandler
        self.runtimeController = runtimeController
        self.playbackStateProvider = playbackStateProvider
    }
}

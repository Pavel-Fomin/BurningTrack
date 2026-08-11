//
//  PurchasedITunesScreenStore.swift
//  TrackList
//
//  Удерживает стабильный граф экрана «Куплено в iTunes».
//
//  Created by Pavel Fomin on 11.08.2026.
//

import Combine
import Foundation

/// Владеет единственными ViewModel и ActionHandler-ами одного navigation destination.
@MainActor
final class PurchasedITunesScreenStore: ObservableObject {

    /// Готовое состояние передаётся Container-ом во View без раскрытия внутренних зависимостей.
    @Published private(set) var screenState: PurchasedITunesScreenState

    private let viewModel: PurchasedITunesMusicViewModel
    private let musicActionHandler: PurchasedITunesMusicActionHandler
    private let trackActionHandler: PurchasedITunesTrackActionHandler
    private var cancellables = Set<AnyCancellable>()

    init(
        viewModel: PurchasedITunesMusicViewModel,
        musicActionHandler: PurchasedITunesMusicActionHandler,
        trackActionHandler: PurchasedITunesTrackActionHandler
    ) {
        self.viewModel = viewModel
        self.musicActionHandler = musicActionHandler
        self.trackActionHandler = trackActionHandler
        self.screenState = viewModel.screenState

        viewModel.$screenState
            .sink { [weak self] state in
                self?.screenState = state
            }
            .store(in: &cancellables)
    }

    /// Передаёт экранное намерение единственному обработчику feature.
    func handle(_ action: PurchasedITunesMusicAction) {
        musicActionHandler.handle(action)
    }

    /// Передаёт строковое намерение handler-у вместе с актуальным отображаемым порядком.
    func handle(_ action: PurchasedITunesTrackAction) {
        trackActionHandler.handle(
            action,
            playbackContext: screenState.tracks
        )
    }
}

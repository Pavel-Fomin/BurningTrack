//
//  MiniPlayerContainer.swift
//  TrackList
//
//  Presentation-граница между PlayerViewModel и MiniPlayerView.
//
//  Created by Pavel Fomin on 10.08.2026.
//

import SwiftUI

/// Наблюдает каноничный Player state и передаёт чистой View готовый ScreenState без второго ObservableObject.
struct MiniPlayerContainer: View {

    /// Единственный реактивный владелец playback-state приложения.
    @ObservedObject private var playerViewModel: PlayerViewModel
    /// Чистый presentation-слой формирует данные для layout.
    private let presenter: MiniPlayerPresenter
    /// Единый action flow выполняет все внешние пользовательские действия.
    private let actionHandler: MiniPlayerActionHandler
    /// Сохранённое значение инициализирует только локальное @State View.
    private let initialIsExpanded: Bool

    init(feature: MiniPlayerFeature) {
        _playerViewModel = ObservedObject(wrappedValue: feature.playerViewModel)
        presenter = feature.presenter
        actionHandler = feature.actionHandler
        initialIsExpanded = feature.initialIsExpanded
    }

    var body: some View {
        MiniPlayerView(
            state: presenter.present(
                miniPlayerState: playerViewModel.miniPlayerState,
                waveformState: playerViewModel.waveformState,
                isCurrentTrackFavorite: playerViewModel.isCurrentTrackFavorite,
                playbackMode: playerViewModel.playbackMode,
                currentTrackDisplayable: playerViewModel.currentTrackDisplayable,
                initialIsExpanded: initialIsExpanded
            ),
            onAction: { actionHandler.handle($0) }
        )
    }
}

//
//  TrackListScreen.swift
//  TrackList
//
//  Список треков(Отображает треклист по ID)
//
//  Created by Pavel Fomin on 19.07.2025.
//

import Foundation
import SwiftUI

struct TrackListScreen: View {
    let trackList: TrackList
    @ObservedObject var playerViewModel: PlayerViewModel
    @StateObject private var viewModel: TrackListViewModel

    /// Фабрика production ViewModel для detail-flow одного треклиста.
    private static let viewModelFactory = TrackListViewModelFactory()

    /// Factory production-обработчика действий detail-flow.
    private let actionHandlerFactory = TrackListFlowActionHandlerFactory()

    /// Обработчик действий detail-flow одного треклиста.
    private var actionHandler: TrackListFlowActionHandler {
        actionHandlerFactory.make(
            reader: viewModel,
            playbackManager: playerViewModel,
            mutator: viewModel,
            renamer: viewModel
        )
    }

    init(trackList: TrackList, playerViewModel: PlayerViewModel) {
        self.trackList = trackList
        self.playerViewModel = playerViewModel
        _viewModel = StateObject(
            wrappedValue: Self.viewModelFactory.make(
                trackList: trackList,
                playerManager: playerViewModel.playerManager
            )
        )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let screenState = viewModel.screenState {
                    TrackListView(
                        state: screenState,
                        onAction: { action in
                            actionHandler.handle(action)
                        },
                        onRequestSnapshot: { trackId in
                            viewModel.requestSnapshotIfNeeded(for: trackId)
                        }
                    )
                }
            }
            .trackListToolbar(
                title: viewModel.screenState?.title ?? viewModel.name,
                onAction: { action in
                    actionHandler.handle(action)
                }
            )
        }
        .onAppear {
            updatePlaybackState()
        }
        .onChange(of: playerViewModel.currentTrackDisplayable?.id) { _, _ in
            updatePlaybackState()
        }
        .onChange(of: playerViewModel.currentContext) { _, _ in
            updatePlaybackState()
        }
        .onChange(of: playerViewModel.isPlaying) { _, _ in
            updatePlaybackState()
        }
    }

    /// Синхронизирует playback-состояние ViewModel с плеером.
    private func updatePlaybackState() {
        viewModel.updatePlaybackState(
            currentTrackId: playerViewModel.currentTrackDisplayable?.id,
            currentContext: playerViewModel.currentContext,
            isPlaying: playerViewModel.isPlaying
        )
    }
}

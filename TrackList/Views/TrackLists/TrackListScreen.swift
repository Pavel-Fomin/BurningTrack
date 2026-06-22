//
//  TrackListScreen.swift
//  TrackList
//
//  Detail-экран одного треклиста.
//
//  Created by Pavel Fomin on 19.07.2025.
//

import Foundation
import SwiftUI

struct TrackListScreen: View {
    let trackList: TrackList
    let playerViewModel: PlayerViewModel
    @StateObject private var viewModel: TrackListViewModel

    /// Фабрика production ViewModel для detail-flow одного треклиста.
    private static let viewModelFactory = TrackListViewModelFactory()

    /// Фабрика production-обработчика действий detail-flow.
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
                playerManager: playerViewModel.fileOperationPlayerManager,
                playbackStateProvider: playerViewModel
            )
        )
    }
    
    var body: some View {
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
        .navigationTitle(viewModel.screenState?.title ?? viewModel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Добавить трек") {
                        actionHandler.handle(.addTrack)
                    }
                    Button("Экспорт") {
                        actionHandler.handle(.export)
                    }
                    Button("Переименовать") {
                        actionHandler.handle(.renameTrackList)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

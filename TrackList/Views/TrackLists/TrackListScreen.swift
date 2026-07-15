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
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel
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
            renamer: viewModel,
            exportProgressViewModel: exportProgressViewModel
        )
    }

    init(
        trackList: TrackList,
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel
    ) {
        self.trackList = trackList
        self.playerViewModel = playerViewModel
        self.exportProgressViewModel = exportProgressViewModel
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
                    Button {
                        actionHandler.handle(.addTrack)
                    } label: {
                        Label("Добавить трек", systemImage: "plus.app")
                    }

                    Button {
                        actionHandler.handle(.export)
                    } label: {
                        Label("Экспорт", systemImage: "externaldrive")
                    }

                    Button {
                        actionHandler.handle(.renameTrackList)
                    } label: {
                        Label("Переименовать", systemImage: "textformat")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

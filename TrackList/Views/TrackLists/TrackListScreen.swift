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
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel
    /// Единый обработчик «Избранного» передаётся в фабрику detail-flow.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Готовые фабрики detail-flow, подготовленные Composition Root.
    let dependencies: TrackListFeatureDependencies
    @StateObject private var viewModel: TrackListViewModel

    /// Обработчик действий detail-flow одного треклиста.
    private var actionHandler: TrackListFlowActionHandler {
        dependencies.actionHandlerFactory.make(
            reader: viewModel,
            mutator: viewModel,
            renamer: viewModel,
            exportProgressViewModel: exportProgressViewModel,
            favoriteTrackActionHandler: favoriteTrackActionHandler
        )
    }

    init(
        trackList: TrackList,
        exportProgressViewModel: ExportProgressViewModel,
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        dependencies: TrackListFeatureDependencies
    ) {
        self.trackList = trackList
        self.exportProgressViewModel = exportProgressViewModel
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: dependencies.viewModelFactory.make(
                trackList: trackList
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
        .navigationTitle(viewModel.screenState?.title ?? viewModel.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ScreenToolbarTitleView(
                    title: viewModel.screenState?.title ?? viewModel.displayName,
                    subtitle: viewModel.screenState?.summary.map(
                        SharedPresentationText.trackCollectionSummary
                    )
                )
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        actionHandler.handle(.addTrack)
                    } label: {
                        Label("Add Tracks", systemImage: "plus.app")
                    }

                    Button {
                        actionHandler.handle(.export)
                    } label: {
                        Label("Export", systemImage: "externaldrive")
                    }

                    if viewModel.screenState?.canRenameTrackList == true {
                        Button {
                            actionHandler.handle(.renameTrackList)
                        } label: {
                            Label("Rename", systemImage: "textformat")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
        }
    }
}

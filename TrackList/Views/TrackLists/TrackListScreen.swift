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
    /// Неизменяемый идентификатор detail-маршрута без snapshot из master-flow.
    let trackListId: UUID
    /// Единый обработчик «Избранного» передаётся в фабрику detail-flow.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Готовые фабрики detail-flow, подготовленные Composition Root.
    let dependencies: TrackListFeatureDependencies
    @StateObject private var viewModel: TrackListViewModel

    /// Обработчик действий detail-flow одного треклиста.
    private var actionHandler: TrackListFlowActionHandler {
        dependencies.actionHandlerFactory.make(
            reader: viewModel,
            favoriteTrackActionHandler: favoriteTrackActionHandler
        )
    }

    init(
        trackListId: UUID,
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        dependencies: TrackListFeatureDependencies
    ) {
        self.trackListId = trackListId
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.dependencies = dependencies
        _viewModel = StateObject(
            wrappedValue: dependencies.viewModelFactory.make(
                trackListId: trackListId
            )
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            switch viewModel.content {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .loaded(let screenState):
                TrackListView(
                    state: screenState,
                    onAction: { action in
                        actionHandler.handle(action)
                    }
                )

            case .notFound:
                ContentUnavailableView(
                    "Tracklist Not Found",
                    systemImage: "music.note.list"
                )

            case .failed:
                ContentUnavailableView {
                    Label("Could Not Load Tracklist", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Try loading this tracklist again.")
                } actions: {
                    Button("Retry") {
                        viewModel.retryInitialLoad()
                    }
                }
            }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .navigationTitle(loadedScreenState?.title ?? "Tracklist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ScreenToolbarTitleView(
                    title: loadedScreenState?.title ?? "Tracklist",
                    subtitle: loadedScreenState?.summary.map(
                        SharedPresentationText.trackCollectionSummary
                    )
                )
            }

            if let screenState = loadedScreenState {
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

                        if screenState.canRenameTrackList {
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

    /// Возвращает готовый ScreenState только для loaded detail-снимка.
    private var loadedScreenState: TrackListScreenState? {
        guard case .loaded(let screenState) = viewModel.content else {
            return nil
        }

        return screenState
    }
}

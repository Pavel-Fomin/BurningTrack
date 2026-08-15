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
    /// ViewModel принадлежит одному detail-маршруту и загружает актуальное состояние по стабильному `trackListId`, а не по снимку master-списка.
    @ObservedObject private var viewModel: TrackListViewModel
    /// Stable handler создан вместе с ViewModel для конкретного detail destination.
    private let actionHandler: TrackListFlowActionHandler

    init(
        viewModel: TrackListViewModel,
        actionHandler: TrackListFlowActionHandler
    ) {
        self.viewModel = viewModel
        self.actionHandler = actionHandler
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
                        actionHandler.handle(.retryInitialLoad)
                    }
                }
            }
        }
        // View отправляет typed lifecycle action; защита от повторного старта и владение загрузкой остаются в ViewModel.
        .task {
            actionHandler.handle(.screenAppeared)
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

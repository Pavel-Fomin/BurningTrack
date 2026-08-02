//
//  PlayerScreen.swift
//  TrackList
//
//  Вкладка “Плеер”
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

struct PlayerScreen: View {

    @ObservedObject var playerViewModel: PlayerViewModel
    @ObservedObject var exportProgressViewModel: ExportProgressViewModel
    /// Единый обработчик «Избранного» передаётся в фабрику Player-flow.
    let favoriteTrackActionHandler: FavoriteTrackActionHandler
    /// Готовая factory экранного flow с явными production-зависимостями.
    let viewModelFactory: PlayerScreenViewModelFactory

    @StateObject private var screenViewModel: PlayerScreenViewModel

    init(
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel,
        favoriteTrackActionHandler: FavoriteTrackActionHandler,
        viewModelFactory: PlayerScreenViewModelFactory
    ) {
        self.playerViewModel = playerViewModel
        self.exportProgressViewModel = exportProgressViewModel
        self.favoriteTrackActionHandler = favoriteTrackActionHandler
        self.viewModelFactory = viewModelFactory
        _screenViewModel = StateObject(
            wrappedValue: viewModelFactory.make(
                playerViewModel: playerViewModel,
                exportProgressViewModel: exportProgressViewModel,
                favoriteTrackActionHandler: favoriteTrackActionHandler
            )
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    PlayerPlaylistView(
                        screenViewModel: screenViewModel
                    )
                }
            }
            .navigationTitle("Player")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            screenViewModel.handle(.saveTrackList)
                        } label: {
                            Label("Save as Tracklist", systemImage: "text.badge.checkmark")
                        }

                        Button {
                            screenViewModel.handle(.exportTrackList)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Export")
                                }
                            } icon: {
                                Image(systemName: "externaldrive")
                            }
                        }

                        Button(role: .destructive) {
                            screenViewModel.handle(.clearTrackList)
                        } label: {
                            Label("Clear Player", systemImage: "paintbrush")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
    }
}

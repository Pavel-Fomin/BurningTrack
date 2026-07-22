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

    @StateObject private var screenViewModel: PlayerScreenViewModel

    /// Фабрика production ViewModel для Player-flow.
    private static let viewModelFactory = PlayerScreenViewModelFactory()

    init(
        playerViewModel: PlayerViewModel,
        exportProgressViewModel: ExportProgressViewModel
    ) {
        self.playerViewModel = playerViewModel
        self.exportProgressViewModel = exportProgressViewModel
        _screenViewModel = StateObject(
            wrappedValue: Self.viewModelFactory.make(
                playerViewModel: playerViewModel,
                exportProgressViewModel: exportProgressViewModel
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

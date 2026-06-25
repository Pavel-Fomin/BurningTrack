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

    @StateObject private var screenViewModel: PlayerScreenViewModel

    /// Фабрика production ViewModel для Player-flow.
    private static let viewModelFactory = PlayerScreenViewModelFactory()

    init(
        playerViewModel: PlayerViewModel
    ) {
        self.playerViewModel = playerViewModel
        _screenViewModel = StateObject(
            wrappedValue: Self.viewModelFactory.make(
                playerViewModel: playerViewModel
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
            .navigationTitle("Плеер")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            screenViewModel.handle(.saveTrackList)
                        } label: {
                            Label("Сохранить", systemImage: "text.badge.checkmark")
                        }

                        Button {
                            screenViewModel.handle(.exportTrackList)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Экспорт")
                                }
                            } icon: {
                                Image(systemName: "externaldrive")
                            }
                        }

                        Button(role: .destructive) {
                            screenViewModel.handle(.clearTrackList)
                        } label: {
                            Label("Очистить плеер", systemImage: "paintbrush")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .miniPlayerHost(
            playerViewModel: playerViewModel
        )
    }
}

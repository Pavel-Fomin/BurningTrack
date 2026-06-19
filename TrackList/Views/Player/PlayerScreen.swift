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
            .playerToolbar(
                trackCount: screenViewModel.state.trackCount,
                onSave: {
                    screenViewModel.handle(.saveTrackList)
                },
                onExport: {
                    screenViewModel.handle(.exportTrackList)
                },
                onClear: {
                    screenViewModel.handle(.clearTrackList)
                }
            )
        }
        .miniPlayerHost(
            playerViewModel: playerViewModel
        )
    }
}

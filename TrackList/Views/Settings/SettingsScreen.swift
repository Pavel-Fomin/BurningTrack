//
//  SettingsScreen.swift
//  TrackList
//
//  Вкладка “Настройки”
//
//  Created by Pavel Fomin on 22.06.2025.
//

import Foundation
import SwiftUI

struct SettingsScreen: View {
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel

    @StateObject private var viewModel: SettingsScreenViewModel

    init(
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel
    ) {
        let settingsManager = AppSettingsManager.shared

        self.init(
            trackListViewModel: trackListViewModel,
            playerViewModel: playerViewModel,
            settingsManager: settingsManager
        )
    }

    init(
        trackListViewModel: TrackListViewModel,
        playerViewModel: PlayerViewModel,
        settingsManager: any SettingsManaging
    ) {
        self.trackListViewModel = trackListViewModel
        self.playerViewModel = playerViewModel

        // Собираем зависимости экрана настроек в composition root.
        let actionHandler = SettingsActionHandler(settingsManager: settingsManager)
        _viewModel = StateObject(
            wrappedValue: SettingsScreenViewModel(
                settingsManager: settingsManager,
                actionHandler: actionHandler
            )
        )
    }

    var body: some View {
        NavigationStack {
            SettingsView(
                state: viewModel.state,
                onAction: viewModel.handle
            )
                .settingsToolbar()
        }
        .miniPlayerHost(
            trackListViewModel: trackListViewModel,
            playerViewModel: playerViewModel
        )
    }
}

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
    let playerViewModel: PlayerViewModel

    @StateObject private var viewModel: SettingsScreenViewModel

    init(
        playerViewModel: PlayerViewModel
    ) {
        let settingsManager = AppSettingsManager.shared

        self.init(
            playerViewModel: playerViewModel,
            settingsManager: settingsManager
        )
    }

    init(
        playerViewModel: PlayerViewModel,
        settingsManager: any SettingsManaging
    ) {
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
                // Системный заголовок даёт экрану нативный Navigation Bar.
                .navigationTitle(SettingsPresentationText.navigationTitle)
        }
        .miniPlayerHost(
            playerViewModel: playerViewModel
        )
    }
}

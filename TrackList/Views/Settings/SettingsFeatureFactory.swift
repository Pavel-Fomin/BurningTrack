//
// "SettingsFeatureFactory.swift"
// TrackList
// Собирает feature-local зависимости экрана настроек.
// Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Собирает ViewModel настроек вне SwiftUI View, сохраняя screen-local StateObject у SettingsScreen.
@MainActor
struct SettingsFeatureFactory {
    private let settingsManager: any SettingsManaging

    init(
        settingsManager: any SettingsManaging
    ) {
        self.settingsManager = settingsManager
    }

    /// Создаёт новый screen-local graph для каждого mount экрана настроек.
    func makeViewModel() -> SettingsScreenViewModel {
        let actionHandler = SettingsActionHandler(
            settingsManager: settingsManager
        )
        return SettingsScreenViewModel(
            settingsManager: settingsManager,
            actionHandler: actionHandler
        )
    }
}

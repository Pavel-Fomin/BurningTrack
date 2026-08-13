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
    @StateObject private var viewModel: SettingsScreenViewModel

    init(
        factory: SettingsFeatureFactory
    ) {
        _viewModel = StateObject(
            wrappedValue: factory.makeViewModel()
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
    }
}

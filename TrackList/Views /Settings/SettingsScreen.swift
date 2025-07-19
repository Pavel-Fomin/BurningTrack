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
    var body: some View {
        VStack(spacing: 0) {
            SettingsToolbar()

            SettingsView()
                .padding(.horizontal, 16)
                .background(Color(.systemGroupedBackground))
        }
    }
}

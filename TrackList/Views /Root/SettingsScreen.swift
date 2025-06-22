//
//  SettingsScreen.swift
//  TrackList
//
//  Вкладка “Настройки”
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

struct SettingsScreen: View {
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                // Заголовок
                Text("Настройки")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.leading)
                    .padding(.top, 8)

                Spacer()

                // Заглушка
                HStack {
                    Spacer()
                    Text("Настройки (в разработке)")
                        .foregroundColor(.secondary)
                    Spacer()
                }

                Spacer()
            }
        }
    }
}

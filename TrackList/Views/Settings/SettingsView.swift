//
//  SettingsView.swift
//  TrackList
//
//  Раздел "Настройки"
//
//  Created by Pavel Fomin on 28.04.2025.
//

import Foundation
import SwiftUI

struct SettingsView: View {

    @ObservedObject private var settingsManager = AppSettingsManager.shared

    var body: some View {
        List {
            Section("Список треков") {
                Toggle(
                    "Отображать метаданные",
                    isOn: Binding(
                        get: {
                            settingsManager.settings.visible.metadata.isTagReadingEnabled
                        },
                        set: { value in
                            settingsManager.setTagReadingEnabled(value)
                        }
                    )
                )

                Toggle(
                    "Показывать «уже в…»",
                    isOn: Binding(
                        get: {
                            settingsManager.settings.visible.library.isTrackListMembershipVisible
                        },
                        set: { value in
                            settingsManager.setTrackListMembershipVisible(value)
                        }
                    )
                )
            }
        }
        .listStyle(.insetGrouped)
    }
}

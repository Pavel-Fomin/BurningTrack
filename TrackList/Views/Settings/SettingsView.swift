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

    let state: SettingsScreenState
    let onAction: (SettingsAction) -> Void

    var body: some View {
        List {
            Section("Список треков") {
                Toggle(
                    "Отображать метаданные",
                    isOn: Binding(
                        get: {
                            state.isTagReadingEnabled
                        },
                        set: { value in
                            onAction(.setTagReadingEnabled(value))
                        }
                    )
                )

                Toggle(
                    "Показывать «уже в…»",
                    isOn: Binding(
                        get: {
                            state.isTrackListMembershipVisible
                        },
                        set: { value in
                            onAction(.setTrackListMembershipVisible(value))
                        }
                    )
                )

                Toggle(
                    "Показывать формат",
                    isOn: Binding(
                        get: {
                            state.isFileFormatVisible
                        },
                        set: { value in
                            onAction(.setFileFormatVisible(value))
                        }
                    )
                )
            }
        }
        .listStyle(.insetGrouped)
    }
}

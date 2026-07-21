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
            Section(SettingsPresentationText.trackListSectionTitle) {
                Toggle(
                    SettingsPresentationText.showMetadataTitle,
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
                    SettingsPresentationText.showTrackListMembershipTitle,
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
                    SettingsPresentationText.showFileFormatTitle,
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

            Section(SettingsPresentationText.librarySectionTitle) {
                Toggle(
                    SettingsPresentationText.showITunesPurchasesTitle,
                    isOn: Binding(
                        get: {
                            state.isPurchasedITunesSourceVisible
                        },
                        set: { value in
                            onAction(.setPurchasedITunesSourceVisible(value))
                        }
                    )
                )

                Text(SettingsPresentationText.iTunesPurchasesFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }
}

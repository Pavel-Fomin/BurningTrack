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

            // Системный footer размещает описание за пределами заливки строки переключателя.
            Section {
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
            } header: {
                Text(SettingsPresentationText.librarySectionTitle)
            } footer: {
                Text(SettingsPresentationText.iTunesPurchasesFooter)
            }
        }
        .listStyle(.insetGrouped)
        .globalBottomScrollReserve()
    }
}

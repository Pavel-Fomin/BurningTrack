//
//  SettingsPresentationText.swift
//  TrackList
//
//  Локализованные подписи presentation-слоя настроек.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Предоставляет локализованные подписи для семантических настроек интерфейса.
enum SettingsPresentationText {
    static var navigationTitle: String {
        String(localized: "Settings")
    }

    static var trackListSectionTitle: String {
        String(localized: "Track List")
    }

    static var showMetadataTitle: String {
        String(localized: "Show Metadata")
    }

    static var showTrackListMembershipTitle: String {
        String(localized: "Show Tracklist Membership")
    }

    static var showFileFormatTitle: String {
        String(localized: "Show File Format")
    }

    static var librarySectionTitle: String {
        String(localized: "Library")
    }

    static var showITunesPurchasesTitle: String {
        String(localized: "Show iTunes Purchases")
    }

    static var iTunesPurchasesFooter: String {
        String(localized: "Shows local iTunes tracks in the library.")
    }
}

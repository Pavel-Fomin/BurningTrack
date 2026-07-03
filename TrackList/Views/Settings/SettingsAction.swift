//
//  SettingsAction.swift
//  TrackList
//
//  Пользовательские действия экрана настроек.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

enum SettingsAction: Equatable {
    case setTagReadingEnabled(Bool)
    case setTrackListMembershipVisible(Bool)
    case setFileFormatVisible(Bool)
    case setPurchasedITunesSourceVisible(Bool)
}

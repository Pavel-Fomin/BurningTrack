//
//  SettingsActionHandler.swift
//  TrackList
//
//  Обработчик пользовательских действий экрана настроек.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

@MainActor
final class SettingsActionHandler {

    private let settingsManager: any SettingsManaging

    init(settingsManager: any SettingsManaging) {
        self.settingsManager = settingsManager
    }

    // Передаёт пользовательские действия существующему менеджеру настроек.
    func handle(_ action: SettingsAction) {
        switch action {
        case .setTagReadingEnabled(let value):
            settingsManager.setTagReadingEnabled(value)

        case .setTrackListMembershipVisible(let value):
            settingsManager.setTrackListMembershipVisible(value)

        case .setFileFormatVisible(let value):
            settingsManager.setFileFormatVisible(value)

        case .setPurchasedITunesSourceVisible(let value):
            settingsManager.setPurchasedITunesSourceVisible(value)
        }
    }
}

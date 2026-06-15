//
//  SettingsScreenViewModel.swift
//  TrackList
//
//  ViewModel экрана настроек.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation
import Combine

@MainActor
final class SettingsScreenViewModel: ObservableObject {

    @Published private(set) var state: SettingsScreenState

    private let settingsManager: any SettingsManaging
    private let actionHandler: SettingsActionHandler
    private var cancellables = Set<AnyCancellable>()

    init(
        settingsManager: any SettingsManaging,
        actionHandler: SettingsActionHandler
    ) {
        self.settingsManager = settingsManager
        self.actionHandler = actionHandler
        self.state = Self.makeState(from: settingsManager.settings)

        // Синхронизируем состояние экрана с актуальными настройками приложения.
        settingsManager.settingsPublisher
            .map(Self.makeState)
            .removeDuplicates()
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &cancellables)
    }

    // Передаёт пользовательское действие выделенному обработчику.
    func handle(_ action: SettingsAction) {
        actionHandler.handle(action)
    }

    // Собирает готовое состояние экрана из модели настроек приложения.
    private static func makeState(from settings: AppSettings) -> SettingsScreenState {
        SettingsScreenState(
            isTagReadingEnabled: settings.visible.metadata.isTagReadingEnabled,
            isTrackListMembershipVisible: settings.visible.library.isTrackListMembershipVisible,
            isFileFormatVisible: settings.visible.library.isFileFormatVisible
        )
    }
}

//
//  MiniPlayerFeatureFactory.swift
//  TrackList
//
//  Собирает production-зависимости MiniPlayer.
//
//  Created by Pavel Fomin on 10.08.2026.
//

import Foundation

/// Собирает неизменяемый feature graph MiniPlayer в composition root без создания зависимостей во View.
@MainActor
struct MiniPlayerFeatureFactory {

    /// Настройки предоставляют начальное раскрытие и persistence action.
    private let settingsManager: any SettingsManaging
    /// Общий доменный маршрут «Избранного» не дублируется MiniPlayer.
    private let favoriteActionHandler: FavoriteTrackActionHandler
    /// Общий navigation-flow получает действие «Показать в фонотеке».
    private let libraryRouter: any MiniPlayerLibraryRouting

    init(
        settingsManager: any SettingsManaging,
        favoriteActionHandler: FavoriteTrackActionHandler,
        libraryRouter: any MiniPlayerLibraryRouting
    ) {
        self.settingsManager = settingsManager
        self.favoriteActionHandler = favoriteActionHandler
        self.libraryRouter = libraryRouter
    }

    /// Создаёт единственные presenter и action handler, используемые всеми размещениями MiniPlayer.
    func make(playerViewModel: PlayerViewModel) -> MiniPlayerFeature {
        MiniPlayerFeature(
            playerViewModel: playerViewModel,
            presenter: MiniPlayerPresenter(),
            actionHandler: MiniPlayerActionHandler(
                playbackProvider: playerViewModel,
                playbackController: playerViewModel,
                favoriteActionHandler: favoriteActionHandler,
                settingsManager: settingsManager,
                libraryRouter: libraryRouter
            ),
            initialIsExpanded: settingsManager.settings.internalSettings.isMiniPlayerExpanded
        )
    }
}

/// Хранит неизменяемые зависимости MiniPlayer, но не владеет playback- или экранным состоянием.
@MainActor
struct MiniPlayerFeature {
    /// Единственный владелец playback-state передаётся только presentation-container.
    let playerViewModel: PlayerViewModel
    /// Чистый преобразователь state остаётся общим для всех размещений панели.
    let presenter: MiniPlayerPresenter
    /// Единая точка обработки всех внешних действий MiniPlayer.
    let actionHandler: MiniPlayerActionHandler
    /// Сохранённое значение передаётся только для первоначальной инициализации локального @State View.
    let initialIsExpanded: Bool
}

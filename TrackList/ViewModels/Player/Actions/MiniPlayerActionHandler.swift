//
//  MiniPlayerActionHandler.swift
//  TrackList
//
//  Обработчик действий мини-плеера.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Передаёт внешние пользовательские действия MiniPlayer в существующие capability приложения.
@MainActor
final class MiniPlayerActionHandler {

    // MARK: - Зависимости

    /// Предоставляет только данные текущего playback, нужные action flow MiniPlayer.
    private let playbackProvider: any MiniPlayerPlaybackProviding

    /// Выполняет только playback-команды, доступные MiniPlayer.
    private let playbackController: any MiniPlayerPlaybackControlling

    /// Повторно использует общий domain-flow «Избранного».
    private let favoriteActionHandler: FavoriteTrackActionHandler

    /// Сохраняет только состояние раскрытия через существующие настройки приложения.
    private let settingsManager: any SettingsManaging

    /// Координатор выполняет переход из действия над треком.
    private let libraryRouter: any MiniPlayerLibraryRouting

    // MARK: - Инициализация

    init(
        playbackProvider: any MiniPlayerPlaybackProviding,
        playbackController: any MiniPlayerPlaybackControlling,
        favoriteActionHandler: FavoriteTrackActionHandler,
        settingsManager: any SettingsManaging,
        libraryRouter: any MiniPlayerLibraryRouting
    ) {
        self.playbackProvider = playbackProvider
        self.playbackController = playbackController
        self.favoriteActionHandler = favoriteActionHandler
        self.settingsManager = settingsManager
        self.libraryRouter = libraryRouter
    }

    // MARK: - Действия

    /// Выполняет действие, выбранное в мини-плеере.
    func handle(_ action: MiniPlayerAction) {
        switch action {
        case .playPause:
            guard hasCurrentTrack else { return }
            playbackController.togglePlayPause()
        case .playPrevious:
            guard hasCurrentTrack else { return }
            playbackController.playPreviousTrack()
        case .playNext:
            guard hasCurrentTrack else { return }
            playbackController.playNextTrack()
        case .seek(let time):
            guard hasCurrentTrack else { return }
            playbackController.seek(to: time)
        case .toggleFavorite:
            toggleFavorite()
        case .toggleShuffle:
            guard hasCurrentTrack else { return }
            playbackController.toggleShuffle()
        case .toggleRepeatAll:
            guard hasCurrentTrack else { return }
            playbackController.toggleRepeatAll()
        case .toggleRepeatOne:
            guard hasCurrentTrack else { return }
            playbackController.toggleRepeatOne()
        case .showCurrentTrackInLibrary:
            showCurrentTrackInLibrary()
        case .setExpanded(let isExpanded):
            settingsManager.setMiniPlayerExpanded(isExpanded)
        }
    }

    // MARK: - Приватные методы

    /// Передаёт текущий трек в существующий координатор перехода к фонотеке.
    private func showCurrentTrackInLibrary() {
        guard let track = playbackProvider.currentTrackDisplayable,
              MiniPlayerActionAvailability.canShowInLibrary(
                miniPlayerState: playbackProvider.miniPlayerState,
                track: track
              ) else {
            return
        }

        libraryRouter.showInLibrary(track)
    }

    /// Передаёт актуальную display-модель в общий domain-flow без оптимистического изменения UI.
    private func toggleFavorite() {
        guard let track = playbackProvider.currentTrackDisplayable else {
            return
        }

        favoriteActionHandler.toggle(
            FavoriteTrackInput(playerTrack: track)
        )
    }

    /// Все playback-действия MiniPlayer требуют конкретного текущего трека.
    private var hasCurrentTrack: Bool {
        playbackProvider.currentTrackDisplayable != nil
    }
}

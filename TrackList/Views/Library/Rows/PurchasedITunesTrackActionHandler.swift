//
//  PurchasedITunesTrackActionHandler.swift
//  TrackList
//
//  Обработчик действий строки купленного iTunes-трека.
//
//  Created by Codex on 02.07.2026.
//

import Foundation

/// Выполняет действия строки iTunes без смешивания с LibraryTrack и без логики во View.
@MainActor
final class PurchasedITunesTrackActionHandler {
    // MARK: - Зависимости

    /// Узкий provider отдаёт актуальный snapshot только в момент действия пользователя.
    private let playbackStateProvider: any PlaybackStateProviding
    /// Команды запуска и toggle не раскрывают handler-у PlayerViewModel.
    private let playbackController: any TrackPlaybackControlling
    /// Маршрутизатор sheet-состояния для выбора треклиста, папки и карточки трека.
    private let sheetRouter: any PurchasedITunesTrackRouting
    /// Исполнитель бизнес-команд приложения.
    private let commandExecutor: any PurchasedITunesTrackPlayerAdding
    /// Общий presentation-адаптер результатов AppCommandExecutor.
    private let commandToastPresenter: AppCommandToastPresenter
    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting
    /// Общий обработчик «Избранного» использует тот же сервис, что и остальные источники треков.
    private let favoriteActionHandler: FavoriteTrackActionHandler
    /// Явно переданный единый share-flow не создаётся и не разрешается строкой.
    private let trackShareActionHandler: any PurchasedITunesTrackSharing

    // MARK: - Инициализация

    /// Создаёт обработчик строки iTunes с явным маршрутом «Избранного».
    init(
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling,
        sheetRouter: any PurchasedITunesTrackRouting,
        commandExecutor: any PurchasedITunesTrackPlayerAdding,
        commandToastPresenter: AppCommandToastPresenter,
        toastPresenter: any ToastPresenting,
        favoriteActionHandler: FavoriteTrackActionHandler,
        trackShareActionHandler: any PurchasedITunesTrackSharing
    ) {
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.sheetRouter = sheetRouter
        self.commandExecutor = commandExecutor
        self.commandToastPresenter = commandToastPresenter
        self.toastPresenter = toastPresenter
        self.favoriteActionHandler = favoriteActionHandler
        self.trackShareActionHandler = trackShareActionHandler
    }

    // MARK: - Действия

    /// Выполняет пользовательское действие строки iTunes.
    func handle(
        _ action: PurchasedITunesTrackAction,
        playbackContext: [PurchasedITunesPlayableTrack]
    ) {
        switch action {
        case .play(let track):
            play(track: track, context: playbackContext)

        case .copy(let track):
            sheetRouter.presentCopyPurchasedITunesToFolder(for: track)

        case .details(let track):
            showDetails(track)

        case .share(let track):
            trackShareActionHandler.sharePurchasedITunesTrack(track)

        case .addToTrackList(let track):
            sheetRouter.presentAddToTrackList(for: track, sourceTrackListId: nil)

        case .addToPlayer(let track):
            addToPlayer(track)

        case .toggleFavorite(let track):
            favoriteActionHandler.toggle(
                FavoriteTrackInput(purchasedITunesTrack: track)
            )
        }
    }

    /// Открывает существующий sheet "О треке" для runtime-модели iTunes.
    private func showDetails(
        _ track: PurchasedITunesPlayableTrack
    ) {
        sheetRouter.presentTrackDetail(track)
    }

    /// Запускает или ставит на паузу текущий iTunes-трек.
    private func play(
        track: PurchasedITunesPlayableTrack,
        context: [PurchasedITunesPlayableTrack]
    ) {
        let playbackState = playbackStateProvider.playbackState
        let isCurrent = playbackState.currentDisplayableId == track.id
            && playbackState.currentContext == .purchasedITunes

        if isCurrent {
            playbackController.togglePlayPause()
        } else {
            playbackController.play(
                track: track,
                context: context.map { $0 as any TrackDisplayable },
                source: .purchasedITunes
            )
        }
    }

    /// Добавляет iTunes-трек в плеер через общий executor приложения.
    private func addToPlayer(
        _ track: PurchasedITunesPlayableTrack
    ) {
        Task {
            do {
                let result = try await commandExecutor.addPurchasedITunesTrackToPlayer(
                    track
                )
                commandToastPresenter.present(result)
            } catch let appError as AppError {
                commandToastPresenter.present(appError)
            } catch {
                toastPresenter.handle(
                    .operationFailed(
                        message: PlayerPresentationText.addPurchasedITunesTrackToPlayerFailedMessage
                    )
                )
            }
        }
    }
}

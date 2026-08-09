//
//  PurchasedITunesTrackActionHandler.swift
//  TrackList
//
//  Обработчик действий строки купленного iTunes-трека.
//
//  Created by Codex on 02.07.2026.
//

import Foundation

/// Явные production-зависимости sheet- и command-действий строки iTunes.
@MainActor
struct PurchasedITunesTrackActionDependencies {
    /// Открывает единый lifecycle-managed Sheet Flow.
    let sheetManager: SheetManager
    /// Выполняет добавление iTunes-трека в очередь плеера.
    let commandExecutor: AppCommandExecutor
    /// Показывает feedback команды добавления в плеер.
    let toastPresenter: any ToastPresenting
}

/// Выполняет действия строки iTunes без смешивания с LibraryTrack и без логики во View.
@MainActor
struct PurchasedITunesTrackActionHandler {
    // MARK: - Зависимости

    /// Готовый snapshot строки не раскрывает ActionHandler-у PlayerViewModel.
    let playbackState: PlaybackStateSnapshot
    /// Команды запуска и toggle не раскрывают handler-у PlayerViewModel.
    let playbackController: any TrackPlaybackControlling
    /// Менеджер sheet-состояния для выбора треклиста и папки назначения.
    private let sheetManager: SheetManager
    /// Исполнитель бизнес-команд приложения.
    private let commandExecutor: AppCommandExecutor
    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting
    /// Общий обработчик «Избранного» использует тот же сервис, что и остальные источники треков.
    private let favoriteActionHandler: FavoriteTrackActionHandler

    // MARK: - Инициализация

    /// Создаёт обработчик строки iTunes с явным маршрутом «Избранного».
    init(
        playbackState: PlaybackStateSnapshot,
        playbackController: any TrackPlaybackControlling,
        actionDependencies: PurchasedITunesTrackActionDependencies,
        favoriteActionHandler: FavoriteTrackActionHandler
    ) {
        self.playbackState = playbackState
        self.playbackController = playbackController
        self.sheetManager = actionDependencies.sheetManager
        self.commandExecutor = actionDependencies.commandExecutor
        self.toastPresenter = actionDependencies.toastPresenter
        self.favoriteActionHandler = favoriteActionHandler
    }

    // MARK: - Состояние строки

    /// Проверяет, является ли трек текущим в контексте купленных iTunes-треков.
    func isCurrent(_ track: PurchasedITunesPlayableTrack) -> Bool {
        playbackState.currentDisplayableId == track.id
            && playbackState.currentContext == .purchasedITunes
    }

    /// Проверяет, играет ли текущий iTunes-трек.
    func isPlaying(_ track: PurchasedITunesPlayableTrack) -> Bool {
        isCurrent(track) && playbackState.isPlaying
    }

    // MARK: - Действия

    /// Выполняет пользовательское действие строки iTunes.
    func handle(_ action: PurchasedITunesTrackAction) {
        switch action {
        case .play(let track, let context):
            play(track: track, context: context)

        case .copy(let track):
            sheetManager.presentCopyPurchasedITunesToFolder(for: track)

        case .details(let track):
            showDetails(track)

        case .share(let track):
            TrackShareActionHandler.shared.sharePurchasedITunesTrack(track)

        case .addToTrackList(let track):
            sheetManager.presentAddToTrackList(for: track)

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
        sheetManager.presentTrackDetail(track)
    }

    /// Запускает или ставит на паузу текущий iTunes-трек.
    private func play(
        track: PurchasedITunesPlayableTrack,
        context: [PurchasedITunesPlayableTrack]
    ) {
        if isCurrent(track) {
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
                AppCommandToastPresenter(
                    toastPresenter: toastPresenter
                ).present(result)
            } catch let appError as AppError {
                AppCommandToastPresenter(
                    toastPresenter: toastPresenter
                ).present(appError)
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

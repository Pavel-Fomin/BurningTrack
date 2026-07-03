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
struct PurchasedITunesTrackActionHandler {
    // MARK: - Зависимости

    /// ViewModel воспроизведения для play/pause сценария.
    let playerViewModel: PlayerViewModel
    /// Менеджер sheet-состояния для выбора треклиста и папки назначения.
    private let sheetManager: SheetManager
    /// Исполнитель бизнес-команд приложения.
    private let commandExecutor: AppCommandExecutor
    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting

    // MARK: - Инициализация

    /// Создаёт обработчик строки iTunes с production-зависимостями по умолчанию.
    init(
        playerViewModel: PlayerViewModel,
        sheetManager: SheetManager? = nil,
        commandExecutor: AppCommandExecutor = .shared,
        toastPresenter: (any ToastPresenting)? = nil
    ) {
        self.playerViewModel = playerViewModel
        self.sheetManager = sheetManager ?? SheetManager.shared
        self.commandExecutor = commandExecutor
        self.toastPresenter = toastPresenter ?? ToastManager.shared
    }

    // MARK: - Состояние строки

    /// Проверяет, является ли трек текущим в контексте купленных iTunes-треков.
    func isCurrent(_ track: PurchasedITunesPlayableTrack) -> Bool {
        playerViewModel.isCurrent(track, in: .purchasedITunes)
    }

    /// Проверяет, играет ли текущий iTunes-трек.
    func isPlaying(_ track: PurchasedITunesPlayableTrack) -> Bool {
        isCurrent(track) && playerViewModel.isPlaying
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

        case .addToTrackList(let track):
            sheetManager.presentAddToTrackList(for: track)

        case .addToPlayer(let track):
            addToPlayer(track)
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
            playerViewModel.togglePlayPause()
        } else {
            playerViewModel.play(track: track, context: context)
        }
    }

    /// Добавляет iTunes-трек в плеер через общий executor приложения.
    private func addToPlayer(
        _ track: PurchasedITunesPlayableTrack
    ) {
        Task {
            do {
                try await commandExecutor.addPurchasedITunesTrackToPlayer(
                    track
                )
            } catch let appError as AppError {
                toastPresenter.handle(appError)
            } catch {
                toastPresenter.handle(
                    .operationFailed(
                        message: "Не удалось добавить iTunes-трек в плеер"
                    )
                )
            }
        }
    }
}

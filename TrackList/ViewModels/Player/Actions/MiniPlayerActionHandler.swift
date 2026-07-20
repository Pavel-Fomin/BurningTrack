//
//  MiniPlayerActionHandler.swift
//  TrackList
//
//  Обработчик действий мини-плеера.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Передаёт действия раскрытого мини-плеера в существующий сценарий представления приложения.
@MainActor
final class MiniPlayerActionHandler {

    // MARK: - Зависимости

    /// ViewModel плеера предоставляет текущий отображаемый трек.
    private let playerViewModel: PlayerViewModel

    /// Координатор выполняет переход из действия над треком.
    private let sheetActionCoordinator: SheetActionCoordinator

    // MARK: - Инициализация

    init(
        playerViewModel: PlayerViewModel,
        sheetActionCoordinator: SheetActionCoordinator
    ) {
        self.playerViewModel = playerViewModel
        self.sheetActionCoordinator = sheetActionCoordinator
    }

    // MARK: - Доступность

    /// Определяет, можно ли показать текущий трек в фонотеке.
    var canShowCurrentTrackInLibrary: Bool {
        switch playerViewModel.miniPlayerState {
        case .empty, .error:
            return false

        case .loading, .playing, .paused:
            break
        }

        guard let track = playerViewModel.currentTrackDisplayable else {
            return false
        }

        return canShowInLibrary(track)
    }

    // MARK: - Действия

    /// Выполняет действие, выбранное в мини-плеере.
    func handle(_ action: MiniPlayerAction) {
        switch action {
        case .showCurrentTrackInLibrary:
            showCurrentTrackInLibrary()
        }
    }

    // MARK: - Приватные методы

    /// Передаёт локальный текущий трек в существующий координатор перехода к фонотеке.
    private func showCurrentTrackInLibrary() {
        guard let track = playerViewModel.currentTrackDisplayable,
              canShowInLibrary(track) else {
            return
        }

        sheetActionCoordinator.handle(
            action: .showInLibrary,
            track: track,
            context: .player
        )
    }

    /// Исключает неподдерживаемые модели и повторно использует правила меню плеера.
    private func canShowInLibrary(_ track: any TrackDisplayable) -> Bool {
        guard !track.isPurchasedITunesRuntimeTrack else {
            return false
        }

        switch track {
        case is LibraryTrack:
            return true

        case let playerTrack as PlayerTrack:
            return canShowInLibrary(source: playerTrack.source)

        case let track as Track:
            return canShowInLibrary(source: track.source)

        default:
            return false
        }
    }

    /// Проверяет доступность действия для известного источника модели очереди или треклиста.
    private func canShowInLibrary(source: TrackSource) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            .showInLibrary,
            source: source,
            context: .player
        )
    }
}

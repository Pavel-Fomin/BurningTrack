//
//  PlayerPresentationActionHandler.swift
//  TrackList
//
//  Обработчик presentation-действий экрана плеера.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

/// Выполняет presentation-действия экрана плеера.
///
/// Handler отвечает за:
/// - открытие sheet сохранения треклиста;
/// - открытие карточки трека;
/// - переход к треку в фонотеке;
/// - открытие сценария перемещения файла.
@MainActor
final class PlayerPresentationActionHandler {

    // MARK: - Dependencies

    /// Хранилище очереди плеера.
    private let playlistManager: PlaylistManager

    /// Менеджер sheet-состояния.
    private let sheetManager: SheetManager

    /// Координатор sheet/navigation действий.
    private let sheetActionCoordinator: SheetActionCoordinator

    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting

    // MARK: - Инициализация

    init(
        playlistManager: PlaylistManager,
        sheetManager: SheetManager,
        sheetActionCoordinator: SheetActionCoordinator,
        toastPresenter: any ToastPresenting
    ) {
        self.playlistManager = playlistManager
        self.sheetManager = sheetManager
        self.sheetActionCoordinator = sheetActionCoordinator
        self.toastPresenter = toastPresenter
    }

    // MARK: - Actions

    /// Открывает сценарий сохранения плейлиста как треклиста.
    func saveTrackList() {
        sheetManager.presentSaveTrackList()
    }

    /// Открывает расположение элемента очереди плеера в фонотеке.
    func showInLibrary(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }
        guard canUseFileActions(track) else { return }

        sheetActionCoordinator.handle(
            action: .showInLibrary,
            track: track,
            context: .player
        )
    }

    /// Открывает сценарий перемещения элемента очереди плеера в другую папку.
    func moveToFolder(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }
        guard canUseFileActions(track) else { return }

        sheetActionCoordinator.handle(
            action: .moveToFolder,
            track: track,
            context: .player
        )
    }

    /// Открывает выбор треклиста для элемента очереди плеера.
    func addToTrackList(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }

        sheetManager.presentAddToTrackList(for: track)
    }

    /// Открывает карточку элемента очереди сразу в режиме редактирования тегов.
    func editTags(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }
        guard canUseFileActions(track) else { return }

        sheetManager.presentTrackDetailForEditing(track)
    }

    /// Открывает карточку выбранного элемента очереди плеера.
    func artworkTap(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }

        sheetManager.present(.trackDetail(track))
    }

    /// Открывает сценарий копирования iTunes-трека из очереди плеера.
    func copyTrack(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }
        guard let purchasedTrack = track.asPurchasedITunesPlayableTrack() else { return }

        sheetManager.presentCopyPurchasedITunesToFolder(for: purchasedTrack)
    }

    // MARK: - Private

    /// Возвращает элемент очереди плеера по его идентификатору.
    private func track(queueItemId: UUID) -> PlayerTrack? {
        playlistManager.tracks.first(where: { $0.id == queueItemId })
    }

    /// Проверяет, можно ли запускать файловый flow для элемента очереди.
    private func canUseFileActions(
        _ track: PlayerTrack
    ) -> Bool {
        guard track.isPurchasedITunesRuntimeTrack else {
            return true
        }

        toastPresenter.handle(
            .operationFailed(message: "Это действие недоступно для iTunes-трека")
        )
        return false
    }
}

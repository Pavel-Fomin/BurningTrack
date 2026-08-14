//
//  PlayerPresentationActionHandler.swift
//  TrackList
//
//  Обработчик presentation-действий экрана плеера.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

/// Выполняет единственный sheet-навигационный маршрут, который нужен Player presentation-flow.
@MainActor
protocol PlayerSheetActionCoordinating {
    /// Открывает трек в фонотеке через существующий глобальный navigation-flow.
    func showInLibrary(_ track: any TrackDisplayable)
}

extension SheetActionCoordinator: PlayerSheetActionCoordinating {}

/// Выполняет presentation-действия экрана плеера.
///
/// Handler отвечает за:
/// - открытие sheet сохранения треклиста;
/// - открытие карточки трека;
/// - переход к треку в фонотеке;
/// - открытие сценария перемещения файла.
@MainActor
final class PlayerPresentationActionHandler {

    // MARK: - Зависимости

    /// Хранилище очереди плеера.
    private let playlistManager: PlaylistManager

    /// Менеджер sheet-состояния.
    private let sheetManager: SheetManager

    /// Координатор sheet/navigation действий.
    private let sheetActionCoordinator: any PlayerSheetActionCoordinating

    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting
    /// Обработчик переходов к значениям музыкальной коллекции.
    private let collectionNavigationHandler: any TrackCollectionIdentifierNavigating
    /// Общий action flow отправки трека.
    private let trackShareActionHandler: TrackShareActionHandler
    /// Общий обработчик «Избранного» выполняет сохранение ниже Player-flow.
    private let favoriteActionHandler: FavoriteTrackActionHandler

    // MARK: - Инициализация

    init(
        playlistManager: PlaylistManager,
        sheetManager: SheetManager,
        sheetActionCoordinator: any PlayerSheetActionCoordinating,
        toastPresenter: any ToastPresenting,
        collectionNavigationHandler: any TrackCollectionIdentifierNavigating,
        trackShareActionHandler: TrackShareActionHandler,
        favoriteActionHandler: FavoriteTrackActionHandler
    ) {
        self.playlistManager = playlistManager
        self.sheetManager = sheetManager
        self.sheetActionCoordinator = sheetActionCoordinator
        self.toastPresenter = toastPresenter
        self.collectionNavigationHandler = collectionNavigationHandler
        self.trackShareActionHandler = trackShareActionHandler
        self.favoriteActionHandler = favoriteActionHandler
    }

    // MARK: - Действия

    /// Открывает сценарий сохранения плейлиста как треклиста.
    func saveTrackList() {
        sheetManager.presentSaveTrackList()
    }

    /// Показывает существующее сообщение для недоступного элемента, не выполняя playback-действие.
    func presentUnavailableTrack(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }

        toastPresenter.handle(
            .trackUnavailable(title: track.title ?? track.fileName)
        )
    }

    /// Открывает расположение элемента очереди плеера в фонотеке.
    func showInLibrary(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }
        guard canShowInLibrary(track) else { return }

        sheetActionCoordinator.showInLibrary(track)
    }

    /// Открывает сценарий перемещения элемента очереди плеера в другую папку.
    func moveToFolder(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }
        guard canUseFileActions(track) else { return }

        sheetManager.presentMoveToFolder(for: track)
    }

    /// Открывает выбор треклиста для элемента очереди плеера.
    func addToTrackList(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }

        sheetManager.presentAddToTrackList(for: track)
    }

    /// Передаёт элемент очереди в общий доменный маршрут «Избранного».
    func toggleFavorite(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }

        favoriteActionHandler.toggle(FavoriteTrackInput(track: track.asTrack()))
    }

    /// Открывает артиста обычного локального элемента очереди.
    func goToArtist(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId),
              track.source == .library else {
            return
        }

        collectionNavigationHandler.openArtist(trackId: track.trackId)
    }

    /// Открывает альбом обычного локального элемента очереди.
    func goToAlbum(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId),
              track.source == .library else {
            return
        }

        collectionNavigationHandler.openAlbum(trackId: track.trackId)
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

        sheetManager.presentTrackDetail(track)
    }

    /// Подготавливает файл элемента очереди через общий flow без работы с URL во View.
    func shareTrack(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }

        trackShareActionHandler.share(track)
    }

    /// Открывает сценарий копирования iTunes-трека из очереди плеера.
    func copyTrack(queueItemId: UUID) {
        guard let track = track(queueItemId: queueItemId) else { return }
        guard let purchasedTrack = track.asPurchasedITunesPlayableTrack() else { return }

        sheetManager.presentCopyPurchasedITunesToFolder(for: purchasedTrack)
    }

    // MARK: - Приватное

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
            .operationFailed(
                message: PlayerPresentationText.purchasedITunesActionUnavailableMessage
            )
        )
        return false
    }

    /// Сверяет showInLibrary с едиными правилами меню, не относя его к файловым операциям.
    private func canShowInLibrary(
        _ track: PlayerTrack
    ) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            .showInLibrary,
            source: track.source,
            context: .player
        )
    }
}

//
//  TrackListPresentationHandler.swift
//  TrackList
//
//  Created by Pavel Fomin on 17.06.2026.
//

import Foundation

/// Обрабатывает presentation-действия detail-flow одного треклиста.
/// Отвечает только за открытие экранов, sheet и глобальные presentation-команды.
@MainActor
final class TrackListPresentationHandler {

    /// Источник read-only данных одного треклиста.
    private let reader: any TrackListReading

    /// Презентер presentation-действий одного треклиста.
    private let presenter: any TrackListPresenting

    /// Презентер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting

    /// Исполнитель команд приложения для runtime-действий iTunes-треков.
    private let commandExecutor: any PurchasedITunesTrackPlayerAdding
    /// Обработчик переходов к значениям музыкальной коллекции.
    private let collectionNavigationHandler: any TrackCollectionNavigating
    /// Общий action flow отправки трека.
    private let trackShareActionHandler: TrackShareActionHandler
    /// Общий обработчик «Избранного» выполняет сохранение вне UI и списка.
    private let favoriteActionHandler: FavoriteTrackActionHandler

    /// Создаёт обработчик presentation-действий одного треклиста.
    init(
        reader: any TrackListReading,
        presenter: any TrackListPresenting,
        toastPresenter: any ToastPresenting,
        commandExecutor: any PurchasedITunesTrackPlayerAdding,
        collectionNavigationHandler: any TrackCollectionNavigating,
        trackShareActionHandler: TrackShareActionHandler,
        favoriteActionHandler: FavoriteTrackActionHandler
    ) {
        self.reader = reader
        self.presenter = presenter
        self.toastPresenter = toastPresenter
        self.commandExecutor = commandExecutor
        self.collectionNavigationHandler = collectionNavigationHandler
        self.trackShareActionHandler = trackShareActionHandler
        self.favoriteActionHandler = favoriteActionHandler
    }

    /// Открывает выбор трека для добавления в текущий треклист.
    func presentAddTrack() {
        presenter.presentAddTrack(to: reader.trackListId)
    }

    /// Открывает переименование текущего треклиста.
    func presentRenameTrackList() {
        presenter.presentRenameTrackList(
            trackListId: reader.trackListId,
            currentName: reader.name
        )
    }

    /// Открывает детали трека из строки треклиста.
    func presentTrackDetail(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }

        presenter.presentTrackDetail(track)
    }

    /// Показывает существующее сообщение о недоступности без обращения к playback handler.
    func presentUnavailableTrack(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }

        toastPresenter.handle(
            .trackUnavailable(title: track.title ?? track.fileName)
        )
    }

    /// Передаёт локальный или iTunes-трек в общий flow подготовки и системной отправки.
    func shareTrack(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }

        trackShareActionHandler.share(track)
    }

    /// Открывает сценарий копирования iTunes-трека из строки треклиста.
    func copyTrack(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }
        guard let purchasedTrack = track.asPurchasedITunesPlayableTrack() else { return }

        presenter.presentCopyPurchasedITunesTrack(purchasedTrack)
    }

    /// Добавляет iTunes-трек из треклиста в очередь плеера.
    func addToPlayer(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }
        guard let purchasedTrack = track.asPurchasedITunesPlayableTrack() else { return }

        Task {
            do {
                let result = try await commandExecutor.addPurchasedITunesTrackToPlayer(
                    purchasedTrack
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

    /// Передаёт строку треклиста в общий доменный маршрут «Избранного».
    func toggleFavorite(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }

        favoriteActionHandler.toggle(FavoriteTrackInput(track: track))
    }

    /// Открывает редактирование тегов строки треклиста.
    func presentTrackTagsEditor(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }
        guard canUseFileActions(track) else { return }

        presenter.presentTrackTagsEditor(track)
    }

    /// Показывает трек из строки треклиста в фонотеке.
    func showInLibrary(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }
        guard canShowInLibrary(track) else { return }

        presenter.showInLibrary(track)
    }

    /// Открывает перемещение файла трека в папку.
    func moveToFolder(rowId: UUID) {
        guard let track = reader.track(forRowId: rowId) else { return }
        guard canUseFileActions(track) else { return }

        presenter.moveToFolder(track)
    }

    /// Открывает артиста обычной локальной строки треклиста.
    func goToArtist(rowId: UUID) {
        guard reader.track(forRowId: rowId)?.source == .library,
              let target = reader.collectionNavigationTarget(forRowId: rowId) else {
            return
        }

        collectionNavigationHandler.openArtist(target: target)
    }

    /// Открывает альбом обычной локальной строки треклиста.
    func goToAlbum(rowId: UUID) {
        guard reader.track(forRowId: rowId)?.source == .library,
              let target = reader.collectionNavigationTarget(forRowId: rowId) else {
            return
        }

        collectionNavigationHandler.openAlbum(target: target)
    }

    /// Проверяет, можно ли запускать файловый flow для строки треклиста.
    private func canUseFileActions(
        _ track: Track
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
        _ track: Track
    ) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            .showInLibrary,
            source: track.source,
            context: .trackList
        )
    }
}

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
    private let commandExecutor: AppCommandExecutor
    /// Обработчик переходов к значениям музыкальной коллекции.
    private let collectionNavigationHandler: TrackCollectionNavigationHandler

    /// Создаёт обработчик presentation-действий одного треклиста.
    init(
        reader: any TrackListReading,
        presenter: any TrackListPresenting,
        toastPresenter: any ToastPresenting,
        commandExecutor: AppCommandExecutor = .shared,
        collectionNavigationHandler: TrackCollectionNavigationHandler = .shared
    ) {
        self.reader = reader
        self.presenter = presenter
        self.toastPresenter = toastPresenter
        self.commandExecutor = commandExecutor
        self.collectionNavigationHandler = collectionNavigationHandler
    }

    /// Открывает выбор трека для добавления в текущий треклист.
    func presentAddTrack() {
        guard let trackListId = reader.currentListId else { return }

        presenter.presentAddTrack(to: trackListId)
    }

    /// Открывает переименование текущего треклиста.
    func presentRenameTrackList() {
        guard let trackListId = reader.currentListId else { return }

        presenter.presentRenameTrackList(
            trackListId: trackListId,
            currentName: reader.name
        )
    }

    /// Открывает детали трека из строки треклиста.
    func presentTrackDetail(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }

        presenter.presentTrackDetail(track)
    }

    /// Открывает сценарий копирования iTunes-трека из строки треклиста.
    func copyTrack(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }
        guard let purchasedTrack = track.asPurchasedITunesPlayableTrack() else { return }

        presenter.presentCopyPurchasedITunesTrack(purchasedTrack)
    }

    /// Добавляет iTunes-трек из треклиста в очередь плеера.
    func addToPlayer(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }
        guard let purchasedTrack = track.asPurchasedITunesPlayableTrack() else { return }

        Task {
            do {
                try await commandExecutor.addPurchasedITunesTrackToPlayer(
                    purchasedTrack
                )
            } catch let appError as AppError {
                toastPresenter.handle(appError)
            } catch {
                toastPresenter.handle(
                    .operationFailed(
                        message: PlayerPresentationText.addPurchasedITunesTrackToPlayerFailedMessage
                    )
                )
            }
        }
    }

    /// Открывает редактирование тегов строки треклиста.
    func presentTrackTagsEditor(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }
        guard canUseFileActions(track) else { return }

        presenter.presentTrackTagsEditor(track)
    }

    /// Показывает трек из строки треклиста в фонотеке.
    func showInLibrary(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }
        guard canUseFileActions(track) else { return }

        presenter.showInLibrary(track)
    }

    /// Открывает перемещение файла трека в папку.
    func moveToFolder(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }) else { return }
        guard canUseFileActions(track) else { return }

        presenter.moveToFolder(track)
    }

    /// Открывает артиста обычной локальной строки треклиста.
    func goToArtist(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }),
              track.source == .library else {
            return
        }

        collectionNavigationHandler.openArtist(trackId: track.trackId)
    }

    /// Открывает альбом обычной локальной строки треклиста.
    func goToAlbum(rowId: UUID) {
        guard let track = reader.tracks.first(where: { $0.id == rowId }),
              track.source == .library else {
            return
        }

        collectionNavigationHandler.openAlbum(trackId: track.trackId)
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
}

//
//  AppCommandToastPresenter.swift
//  TrackList
//
//  Преобразование результатов команд приложения в Toast-события.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Отображает результаты AppCommandExecutor через существующий Toast-presenter.
@MainActor
struct AppCommandToastPresenter {

    /// Конечный presentation-адаптер пользовательских сообщений.
    private let toastPresenter: any ToastPresenting

    /// Создаёт presenter с явно переданным Toast-адаптером.
    init(toastPresenter: any ToastPresenting) {
        self.toastPresenter = toastPresenter
    }

    /// Показывает пользовательское сообщение для доменной ошибки.
    func present(_ error: AppError) {
        toastPresenter.handle(error)
    }

    /// Отображает успешное перемещение трека.
    func present(_ result: MoveTrackSuccess) {
        let snapshot = result.snapshot
        toastPresenter.handle(
            .trackMovedInLibrary(
                title: snapshot?.title ?? snapshot?.fileName ?? "",
                artist: snapshot?.artist ?? "",
                artwork: ArtworkRequest(
                    trackId: result.trackId,
                    snapshot: snapshot,
                    purpose: .toast
                ),
                folderName: result.destinationFolderName
            )
        )
    }

    /// Отображает успешное копирование iTunes-трека по исходной runtime-модели.
    func present(
        _ result: CopyPurchasedITunesTrackSuccess,
        sourceTrack: PurchasedITunesPlayableTrack
    ) {
        toastPresenter.handle(
            .trackCopiedFromITunes(
                title: sourceTrack.title ?? sourceTrack.fileName,
                artist: sourceTrack.artist ?? "",
                artwork: purchasedITunesArtwork(for: sourceTrack),
                folderName: result.destinationFolderName
            )
        )
    }

    /// Отображает успешное переименование файла.
    func present(_ result: RenameTrackSuccess) {
        toastPresenter.handle(
            .fileRenamed(newName: result.finalFileName)
        )
    }

    /// Отображает добавление одного файлового трека в треклист.
    func present(_ result: TrackAddedToTrackListSuccess) async {
        let event = await TrackToastEventBuilder.trackAddedToTrackList(
            trackId: result.addedTrack.trackId,
            fallbackFileName: result.addedTrack.fileName,
            trackListName: result.trackListName
        )
        toastPresenter.handle(event)
    }

    /// Отображает итог массового добавления файловых треков в треклист.
    func present(_ result: TracksAddedToTrackListSuccess) {
        toastPresenter.handle(
            .tracksAddedToTrackList(
                count: result.addedTrackIds.count,
                name: result.trackListName
            )
        )
    }

    /// Отображает добавление одного или нескольких iTunes-треков в треклист.
    func present(_ result: PurchasedITunesTracksAddedToTrackListSuccess) {
        if result.addedTracks.count == 1, let track = result.addedTracks.first {
            toastPresenter.handle(
                .trackAddedToTrackList(
                    title: track.title ?? track.fileName,
                    artist: track.artist ?? "",
                    artwork: purchasedITunesArtwork(for: track),
                    trackListName: result.trackListName
                )
            )
            return
        }

        toastPresenter.handle(
            .tracksAddedToTrackList(
                count: result.addedTracks.count,
                name: result.trackListName
            )
        )
    }

    /// Отображает создание треклиста через семантическое событие успешного результата.
    func present(_ result: TrackListCreatedSuccess) {
        toastPresenter.handle(.trackListSaved(name: result.trackListName))
    }

    /// Отображает переименование треклиста.
    func present(_ result: TrackListRenamedSuccess) {
        toastPresenter.handle(.trackListRenamed(newName: result.trackListName))
    }

    /// Отображает удаление трека из треклиста.
    func present(_ result: TrackRemovedFromTrackListSuccess) async {
        let track = result.removedTrack

        guard track.isPurchasedITunesRuntimeTrack == false else {
            toastPresenter.handle(
                .trackRemovedFromTrackList(
                    title: track.title ?? track.fileName,
                    artist: track.artist ?? "",
                    artwork: purchasedITunesArtwork(for: track)
                )
            )
            return
        }

        let event = await TrackToastEventBuilder.trackRemovedFromTrackList(
            trackId: track.trackId,
            fallbackFileName: track.fileName
        )
        toastPresenter.handle(event)
    }

    /// Отображает добавление одного файлового трека в плеер.
    func present(_ result: TrackAddedToPlayerSuccess) {
        let track = result.addedTrack
        toastPresenter.handle(
            .trackAddedToPlayer(
                title: result.snapshot?.title ?? track.fileName,
                artist: result.snapshot?.artist ?? "",
                artwork: ArtworkRequest(
                    trackId: track.trackId,
                    snapshot: result.snapshot,
                    purpose: .toast
                )
            )
        )
    }

    /// Отображает добавление iTunes-трека в плеер.
    func present(_ result: PurchasedITunesTrackAddedToPlayerSuccess) {
        let track = result.addedTrack
        toastPresenter.handle(
            .trackAddedToPlayer(
                title: track.title ?? track.fileName,
                artist: track.artist ?? "",
                artwork: purchasedITunesArtwork(for: track)
            )
        )
    }

    /// Отображает добавление одного или нескольких файловых треков в плеер.
    func present(_ result: TracksAddedToPlayerSuccess) {
        if result.addedTracks.count == 1, let track = result.addedTracks.first {
            present(track)
            return
        }

        toastPresenter.handle(
            .tracksAddedToPlayer(count: result.addedTracks.count)
        )
    }

    /// Отображает удаление трека из плеера.
    func present(_ result: TrackRemovedFromPlayerSuccess) async {
        let track = result.removedTrack

        guard track.isPurchasedITunesRuntimeTrack == false else {
            toastPresenter.handle(
                .trackRemovedFromPlayer(
                    title: track.title ?? track.fileName,
                    artist: track.artist ?? "",
                    artwork: purchasedITunesArtwork(for: track)
                )
            )
            return
        }

        let event = await TrackToastEventBuilder.trackRemovedFromPlayer(
            trackId: track.trackId,
            fallbackFileName: track.fileName
        )
        toastPresenter.handle(event)
    }

    /// Отображает успешную очистку очереди плеера.
    func present(_: PlayerClearedSuccess) {
        toastPresenter.handle(.playerCleared)
    }

    /// Отображает итоговое сохранение файла, тегов или обложки.
    func present(_ result: TrackEditsSavedSuccess) {
        if result.didUpdateTagsOrArtwork {
            let snapshot = result.snapshot
            toastPresenter.handle(
                .tagsUpdated(
                    title: snapshot?.title ?? snapshot?.fileName ?? result.finalFileName,
                    artist: snapshot?.artist ?? "",
                    artwork: ArtworkRequest(
                        trackId: result.trackId,
                        snapshot: snapshot,
                        purpose: .toast
                    )
                )
            )
            return
        }

        toastPresenter.handle(.fileRenamed(newName: result.finalFileName))
    }

    /// Отображает успешное сохранение тегов или обложки.
    func present(_ result: TrackTagsUpdatedSuccess) {
        let snapshot = result.snapshot
        toastPresenter.handle(
            .tagsUpdated(
                title: snapshot?.title ?? "",
                artist: snapshot?.artist ?? "",
                artwork: ArtworkRequest(
                    trackId: result.trackId,
                    snapshot: snapshot,
                    purpose: .toast
                )
            )
        )
    }

    /// Готовит запрос обложки iTunes-трека без файлового metadata cache.
    private func purchasedITunesArtwork(
        for track: any TrackDisplayable & PurchasedITunesTrackRepresentable
    ) -> ArtworkRequest? {
        guard let artworkData = track.artworkData else { return nil }

        return ArtworkRequest(
            trackId: track.trackId,
            artworkData: artworkData,
            purpose: .toast,
            sourceIdentifier: .mediaLibrary(trackId: track.trackId)
        )
    }
}

//
//  PurchasedITunesTrackActionHandlerTests.swift
//  TrackListTests
//
//  Проверки маршрутизации действий строки «Куплено в iTunes».
//
//  Created by Pavel Fomin on 12.08.2026.
//

import Combine
import Foundation
import XCTest
@testable import TrackList

@MainActor
final class PurchasedITunesTrackActionHandlerTests: XCTestCase {

    /// Проверяет feature-локальные маршруты, share-flow и доменное избранное без SheetManager во View.
    func testRoutesNonPlaybackActionsThroughInjectedCapabilities() {
        let track = makeTrack()
        let router = PurchasedITunesTrackRouterSpy()
        let shareHandler = PurchasedITunesTrackShareSpy()
        let favoritesService = PurchasedITunesFavoritesServiceSpy()
        let handler = makeHandler(
            router: router,
            favoritesService: favoritesService,
            shareHandler: shareHandler
        )

        handler.handle(.copy(track: track), playbackContext: [track])
        handler.handle(.details(track: track), playbackContext: [track])
        handler.handle(.addToTrackList(track: track), playbackContext: [track])
        handler.handle(.share(track: track), playbackContext: [track])
        handler.handle(.toggleFavorite(track: track), playbackContext: [track])

        XCTAssertEqual(router.copiedTrackIDs, [track.trackId])
        XCTAssertEqual(router.detailsTrackIDs, [track.trackId])
        XCTAssertEqual(router.addedToTrackListTrackIDs, [track.trackId])
        XCTAssertEqual(router.addedToTrackListSourceIDs, [nil])
        XCTAssertEqual(shareHandler.sharedTrackIDs, [track.trackId])
        XCTAssertEqual(favoritesService.toggledTrackIDs, [track.trackId])
    }

    /// Проверяет toggle текущей строки и запуск новой строки с полным screen-контекстом.
    func testPlayUsesCurrentPlaybackSnapshotAndScreenContext() {
        let currentTrack = makeTrack(id: 1)
        let nextTrack = makeTrack(id: 2)
        let playbackStateProvider = PurchasedITunesPlaybackStateSpy(
            state: PlaybackStateSnapshot(
                currentDisplayableId: currentTrack.id,
                currentTrackId: currentTrack.trackId,
                currentContext: .purchasedITunes,
                currentContextSource: .purchasedITunes,
                isPlaying: true
            )
        )
        let playbackController = PurchasedITunesPlaybackControllerSpy()
        let handler = makeHandler(
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController
        )

        handler.handle(.play(track: currentTrack), playbackContext: [currentTrack, nextTrack])

        XCTAssertEqual(playbackController.toggleCallCount, 1)
        XCTAssertTrue(playbackController.playedTrackIDs.isEmpty)

        playbackStateProvider.set(
            PlaybackStateSnapshot(
                currentDisplayableId: nil,
                currentTrackId: nil,
                currentContext: nil,
                currentContextSource: nil,
                isPlaying: false
            )
        )
        handler.handle(.play(track: nextTrack), playbackContext: [currentTrack, nextTrack])

        XCTAssertEqual(playbackController.playedTrackIDs, [nextTrack.trackId])
        XCTAssertEqual(playbackController.playedContextIDs, [[currentTrack.id, nextTrack.id]])
        XCTAssertEqual(playbackController.playedSources, [.purchasedITunes])
    }

    /// Проверяет асинхронное добавление в плеер через injected executor и общий toast-presentation.
    func testAddToPlayerUsesInjectedExecutor() async {
        let track = makeTrack()
        let executor = PurchasedITunesPlayerAddingSpy()
        let toastPresenter = ExportRequestToastPresenterSpy()
        let handler = makeHandler(
            commandExecutor: executor,
            toastPresenter: toastPresenter
        )

        handler.handle(.addToPlayer(track: track), playbackContext: [track])
        await yieldToCommandTask()

        XCTAssertEqual(executor.addedTrackIDs, [track.trackId])
        XCTAssertEqual(toastPresenter.events.count, 1)
        XCTAssertTrue(toastPresenter.errors.isEmpty)
    }

    /// Собирает handler с явно подставленными capabilities строкового flow.
    private func makeHandler(
        playbackStateProvider: PurchasedITunesPlaybackStateSpy? = nil,
        playbackController: PurchasedITunesPlaybackControllerSpy? = nil,
        router: PurchasedITunesTrackRouterSpy? = nil,
        commandExecutor: PurchasedITunesPlayerAddingSpy? = nil,
        toastPresenter: ExportRequestToastPresenterSpy? = nil,
        favoritesService: PurchasedITunesFavoritesServiceSpy? = nil,
        shareHandler: PurchasedITunesTrackShareSpy? = nil
    ) -> PurchasedITunesTrackActionHandler {
        let resolvedPlaybackStateProvider = playbackStateProvider
            ?? PurchasedITunesPlaybackStateSpy()
        let resolvedPlaybackController = playbackController
            ?? PurchasedITunesPlaybackControllerSpy()
        let resolvedRouter = router ?? PurchasedITunesTrackRouterSpy()
        let resolvedCommandExecutor = commandExecutor
            ?? PurchasedITunesPlayerAddingSpy()
        let resolvedToastPresenter = toastPresenter
            ?? ExportRequestToastPresenterSpy()
        let resolvedFavoritesService = favoritesService
            ?? PurchasedITunesFavoritesServiceSpy()
        let resolvedShareHandler = shareHandler ?? PurchasedITunesTrackShareSpy()

        return PurchasedITunesTrackActionHandler(
            playbackStateProvider: resolvedPlaybackStateProvider,
            playbackController: resolvedPlaybackController,
            sheetRouter: resolvedRouter,
            commandExecutor: resolvedCommandExecutor,
            commandToastPresenter: AppCommandToastPresenter(
                toastPresenter: resolvedToastPresenter
            ),
            toastPresenter: resolvedToastPresenter,
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: resolvedFavoritesService
            ),
            trackShareActionHandler: resolvedShareHandler
        )
    }

    /// Создаёт iTunes-адаптер с постоянным UUID, аналогичным production-пути MediaPlayer.
    private func makeTrack(
        id: UInt64 = 1
    ) -> PurchasedITunesPlayableTrack {
        PurchasedITunesPlayableTrack(
            track: PurchasedITunesTrack(
                id: id,
                title: "Track \(id)",
                artist: "Artist",
                album: nil,
                year: nil,
                genre: nil,
                dateAdded: Date(timeIntervalSince1970: 0),
                artworkData: nil,
                duration: 1,
                assetURL: URL(fileURLWithPath: "/tmp/action-\(id).m4a")
            )
        )
    }

    /// Даёт завершиться Task, созданной action handler-ом для AppCommandExecutor.
    private func yieldToCommandTask() async {
        for _ in 0..<6 {
            await Task.yield()
        }
    }
}

/// Сохраняет sheet-запросы строки без создания SheetManager.
@MainActor
private final class PurchasedITunesTrackRouterSpy: PurchasedITunesTrackRouting {
    private(set) var copiedTrackIDs: [UUID] = []
    private(set) var detailsTrackIDs: [UUID] = []
    private(set) var addedToTrackListTrackIDs: [UUID] = []
    private(set) var addedToTrackListSourceIDs: [UUID?] = []

    func presentCopyPurchasedITunesToFolder(for track: PurchasedITunesPlayableTrack) {
        copiedTrackIDs.append(track.trackId)
    }

    func presentTrackDetail(_ track: any TrackDisplayable) {
        detailsTrackIDs.append(track.trackId)
    }

    func presentAddToTrackList(for track: any TrackDisplayable, sourceTrackListId: UUID?) {
        addedToTrackListTrackIDs.append(track.trackId)
        addedToTrackListSourceIDs.append(sourceTrackListId)
    }
}

/// Сохраняет вызовы плеера и переданный полный playback-контекст.
@MainActor
private final class PurchasedITunesPlaybackControllerSpy: TrackPlaybackControlling {
    private(set) var toggleCallCount = 0
    private(set) var playedTrackIDs: [UUID] = []
    private(set) var playedContextIDs: [[UUID]] = []
    private(set) var playedSources: [PlaybackContextSource] = []

    func togglePlayPause() {
        toggleCallCount += 1
    }

    func play(
        track: any TrackDisplayable,
        context: [any TrackDisplayable],
        source: PlaybackContextSource
    ) {
        playedTrackIDs.append(track.trackId)
        playedContextIDs.append(context.map(\.id))
        playedSources.append(source)
    }
}

/// Публикует текущий playback snapshot и позволяет тесту сменить его до действия строки.
@MainActor
private final class PurchasedITunesPlaybackStateSpy: PlaybackStateProviding {
    private let subject: CurrentValueSubject<PlaybackStateSnapshot, Never>

    init(
        state: PlaybackStateSnapshot = PlaybackStateSnapshot(
            currentDisplayableId: nil,
            currentTrackId: nil,
            currentContext: nil,
            currentContextSource: nil,
            isPlaying: false
        )
    ) {
        subject = CurrentValueSubject(state)
    }

    var playbackState: PlaybackStateSnapshot { subject.value }
    var currentDisplayableId: UUID? { playbackState.currentDisplayableId }
    var currentTrackId: UUID? { playbackState.currentTrackId }
    var currentContext: PlaybackContext? { playbackState.currentContext }
    var currentContextSource: PlaybackContextSource? { playbackState.currentContextSource }
    var isPlaying: Bool { playbackState.isPlaying }

    var playbackStatePublisher: AnyPublisher<PlaybackStateSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }

    func set(_ state: PlaybackStateSnapshot) {
        subject.send(state)
    }
}

/// Фиксирует ровно одну команду добавления iTunes-элемента в общий плеер.
private final class PurchasedITunesPlayerAddingSpy: PurchasedITunesTrackPlayerAdding {
    private(set) var addedTrackIDs: [UUID] = []

    func addPurchasedITunesTrackToPlayer(
        _ track: PurchasedITunesPlayableTrack
    ) async throws -> PurchasedITunesTrackAddedToPlayerSuccess {
        addedTrackIDs.append(track.trackId)
        return PurchasedITunesTrackAddedToPlayerSuccess(
            addedTrack: PlayerTrack.make(from: track)
        )
    }
}

/// Фиксирует передачу assetURL в единый share-flow без неявного singleton.
@MainActor
private final class PurchasedITunesTrackShareSpy: PurchasedITunesTrackSharing {
    private(set) var sharedTrackIDs: [UUID] = []

    func sharePurchasedITunesTrack(_ track: PurchasedITunesPlayableTrack) {
        sharedTrackIDs.append(track.trackId)
    }
}

/// Заменяет системный треклист «Избранное» и хранит полученную логическую идентичность.
@MainActor
private final class PurchasedITunesFavoritesServiceSpy: FavoritesServicing {
    private(set) var toggledTrackIDs: [UUID] = []

    func loadFavoriteTrackIds() throws -> Set<UUID> { [] }
    func isFavorite(trackId: UUID) throws -> Bool { false }
    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult { .added }
    func remove(trackId: UUID) throws -> FavoritesMutationResult { .removed }

    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        toggledTrackIDs.append(track.trackId)
        return .added
    }
}

//
//  PurchasedITunesFeatureFactory.swift
//  TrackList
//
//  Собирает production-граф feature «Куплено в iTunes».
//
//  Created by Pavel Fomin on 11.08.2026.
//

import Foundation

/// Собирает единый graph iTunes destination без разрешения глобальных зависимостей внутри feature.
@MainActor
struct PurchasedITunesFeatureFactory {

    private let musicProvider: any PurchasedITunesMusicProviding
    private let sortModePersistence: any PurchasedITunesTrackSortModePersisting
    private let playbackStateProvider: any PlaybackStateProviding
    private let playbackController: any TrackPlaybackControlling
    private let favoriteTrackIdsProvider: any FavoriteTrackIdsProviding
    private let favoriteActionHandler: FavoriteTrackActionHandler
    private let trackShareActionHandler: TrackShareActionHandler
    private let sheetManager: SheetManager
    private let commandExecutor: AppCommandExecutor
    private let commandToastPresenter: AppCommandToastPresenter
    private let toastPresenter: any ToastPresenting
    private let viewControllerProvider: any ViewControllerProviding

    /// Принимает только уже собранные production-зависимости Composition Root.
    init(
        musicProvider: any PurchasedITunesMusicProviding,
        sortModePersistence: any PurchasedITunesTrackSortModePersisting,
        playbackStateProvider: any PlaybackStateProviding,
        playbackController: any TrackPlaybackControlling,
        favoriteTrackIdsProvider: any FavoriteTrackIdsProviding,
        favoriteActionHandler: FavoriteTrackActionHandler,
        trackShareActionHandler: TrackShareActionHandler,
        sheetManager: SheetManager,
        commandExecutor: AppCommandExecutor,
        commandToastPresenter: AppCommandToastPresenter,
        toastPresenter: any ToastPresenting,
        viewControllerProvider: any ViewControllerProviding
    ) {
        self.musicProvider = musicProvider
        self.sortModePersistence = sortModePersistence
        self.playbackStateProvider = playbackStateProvider
        self.playbackController = playbackController
        self.favoriteTrackIdsProvider = favoriteTrackIdsProvider
        self.favoriteActionHandler = favoriteActionHandler
        self.trackShareActionHandler = trackShareActionHandler
        self.sheetManager = sheetManager
        self.commandExecutor = commandExecutor
        self.commandToastPresenter = commandToastPresenter
        self.toastPresenter = toastPresenter
        self.viewControllerProvider = viewControllerProvider
    }

    /// Создаёт Container, не раскрывая LibraryScreen внутренние зависимости feature.
    func makeContainer(
        exportProgressViewModel: ExportProgressViewModel,
        revealRequest: LibraryRevealRequest?,
        onRevealHandled: @escaping (UUID) -> Void
    ) -> PurchasedITunesContainer {
        PurchasedITunesContainer(
            featureFactory: self,
            exportProgressViewModel: exportProgressViewModel,
            revealRequest: revealRequest,
            onRevealHandled: onRevealHandled
        )
    }

    /// Собирает стабильные объекты одного destination до передачи их StateObject-контейнеру.
    func makeScreenStore(
        exportProgressViewModel: ExportProgressViewModel
    ) -> PurchasedITunesScreenStore {
        let viewModel = PurchasedITunesMusicViewModel(
            provider: musicProvider,
            sortModePersistence: sortModePersistence,
            favoriteTrackIdsProvider: favoriteTrackIdsProvider,
            playbackStateProvider: playbackStateProvider,
            presenter: PurchasedITunesPresenter(
                artworkBadgeStateFactory: TrackArtworkBadgeStateFactory()
            )
        )
        let musicActionHandler = PurchasedITunesMusicActionHandler(
            viewModel: viewModel,
            exportProgressViewModel: exportProgressViewModel,
            viewControllerProvider: viewControllerProvider,
            toastPresenter: toastPresenter
        )
        let trackActionHandler = PurchasedITunesTrackActionHandler(
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            sheetRouter: sheetManager,
            commandExecutor: commandExecutor,
            commandToastPresenter: commandToastPresenter,
            toastPresenter: toastPresenter,
            favoriteActionHandler: favoriteActionHandler,
            trackShareActionHandler: trackShareActionHandler
        )

        return PurchasedITunesScreenStore(
            viewModel: viewModel,
            musicActionHandler: musicActionHandler,
            trackActionHandler: trackActionHandler
        )
    }
}

import Foundation

/// Выполняет команды строки фонотеки, не смешивая их с UI.
@MainActor
struct LibraryTrackCommandHandler {
    let sheetManager: SheetManager
    let playbackHandler: LibraryTrackPlaybackHandler
    let presentationHandler: LibraryTrackPresentationHandler
    let cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler
    let collectionNavigationHandler: TrackCollectionNavigationHandler
    /// Share flow передаётся Composition Root, поэтому строка не обращается к singleton.
    let trackShareActionHandler: TrackShareActionHandler
    /// Выполняет команду добавления в плеер без обращения строки к application singleton.
    let commandExecutor: AppCommandExecutor
    let toastManager: ToastManager
    let sheetActionCoordinator: SheetActionCoordinator
    /// Общий обработчик «Избранного» сохраняет состояние и публикует подтверждённое событие.
    private let favoriteActionHandler: FavoriteTrackActionHandler
    /// Экранный маршрут нужен только для selection, которое относится к LibraryTracks, а не к строке.
    private let screenActionHandler: LibraryTracksActionHandler?
    /// Legacy collection flow передаёт замыкание до его отдельного этапа экранной архитектуры.
    private let onToggleSelection: ((UUID) -> Void)?
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void

    /// Выполняет действие строки.
    func handle(_ action: LibraryTrackAction) {
        switch action {
        case .tapRow(let track, let context):
            playbackHandler.handleTap(track: track, context: context)
        case .tapArtwork(let track):
            sheetManager.present(.trackDetail(track))
        case .share(let track):
            trackShareActionHandler.share(track)
        case .addToPlayer(let trackId):
            addToPlayer(trackId: trackId)
        case .addToTrackList(let track):
            sheetManager.presentAddToTrackList(for: track)
        case .toggleFavorite(let track):
            favoriteActionHandler.toggle(FavoriteTrackInput(libraryTrack: track))
        case .goToArtist(let trackId):
            collectionNavigationHandler.openArtist(trackId: trackId)
        case .goToAlbum(let trackId):
            collectionNavigationHandler.openAlbum(trackId: trackId)
        case .moveToFolder(let track):
            sheetActionCoordinator.handle(
                action: .moveToFolder,
                track: track,
                context: .library
            )
        case .editTags(let track):
            sheetManager.presentTrackDetailForEditing(track)
        case .rename(let trackId, let strategy):
            onRenameTrack(trackId, strategy)
        case .toggleSelection(let trackId):
            // Selection возвращается в typed screen action, а не меняется Binding-ом строки.
            if let screenActionHandler {
                screenActionHandler.handle(.trackSelectionToggled(trackId))
            } else {
                onToggleSelection?(trackId)
            }
        case .requestSnapshot(let trackId):
            presentationHandler.requestSnapshotIfNeeded(for: trackId)
        case .trackDidAppear(let trackId):
            cloudAvailabilityActionHandler.handle(
                .visibleTrackDidAppear(trackId: trackId)
            )
        case .trackDidDisappear(let trackId):
            cloudAvailabilityActionHandler.handle(
                .visibleTrackDidDisappear(trackId: trackId)
            )
        case .retryCloudDownload(let trackId):
            cloudAvailabilityActionHandler.handle(
                .retryDownload(trackId: trackId)
            )
        }
    }

    /// Создаёт обработчик строки с единым доменным маршрутом «Избранного».
    init(
        sheetManager: SheetManager,
        playbackHandler: LibraryTrackPlaybackHandler,
        presentationHandler: LibraryTrackPresentationHandler,
        cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler,
        collectionNavigationHandler: TrackCollectionNavigationHandler,
        trackShareActionHandler: TrackShareActionHandler,
        commandExecutor: AppCommandExecutor,
        toastManager: ToastManager,
        sheetActionCoordinator: SheetActionCoordinator,
        favoriteActionHandler: FavoriteTrackActionHandler,
        screenActionHandler: LibraryTracksActionHandler? = nil,
        onToggleSelection: ((UUID) -> Void)? = nil,
        onRenameTrack: @escaping (UUID, FileRenameStrategy) -> Void
    ) {
        self.sheetManager = sheetManager
        self.playbackHandler = playbackHandler
        self.presentationHandler = presentationHandler
        self.cloudAvailabilityActionHandler = cloudAvailabilityActionHandler
        self.collectionNavigationHandler = collectionNavigationHandler
        self.trackShareActionHandler = trackShareActionHandler
        self.commandExecutor = commandExecutor
        self.toastManager = toastManager
        self.sheetActionCoordinator = sheetActionCoordinator
        self.favoriteActionHandler = favoriteActionHandler
        self.screenActionHandler = screenActionHandler
        self.onToggleSelection = onToggleSelection
        self.onRenameTrack = onRenameTrack
    }

    /// Добавляет трек в плеер через общий executor приложения.
    private func addToPlayer(trackId: UUID) {
        Task {
            do {
                let result = try await commandExecutor.addTrackToPlayer(
                    trackId: trackId
                )
                AppCommandToastPresenter(
                    toastPresenter: toastManager
                ).present(result)
            } catch let appError as AppError {
                AppCommandToastPresenter(
                    toastPresenter: toastManager
                ).present(appError)
            } catch {
                toastManager.handle(
                    .operationFailed(
                        message: PlayerPresentationText.addTrackToPlayerFailedMessage
                    )
                )
            }
        }
    }
}

/// Действия экранного наблюдения за iCloud-файлами фонотеки.
enum LibraryCloudAvailabilityAction {
    case screenDidAppear
    case visibleTrackDidAppear(trackId: UUID)
    case visibleTrackDidDisappear(trackId: UUID)
    case screenDidDisappear
    case retryDownload(trackId: UUID)
}

/// Передаёт намерения View контроллеру общего iCloud-наблюдения текущего экрана.
@MainActor
struct LibraryCloudAvailabilityActionHandler {
    let controller: LibraryCloudAvailabilityScreenController

    /// Выполняет действие iCloud-наблюдения без доступа View к файловому менеджеру.
    func handle(
        _ action: LibraryCloudAvailabilityAction
    ) {
        switch action {
        case .screenDidAppear:
            controller.screenDidAppear()
        case .visibleTrackDidAppear(let trackId):
            controller.rowDidAppear(trackId: trackId)
        case .visibleTrackDidDisappear(let trackId):
            controller.rowDidDisappear(trackId: trackId)
        case .screenDidDisappear:
            controller.screenDidDisappear()
        case .retryDownload(let trackId):
            Task {
                await controller.retryDownloading(trackId: trackId)
            }
        }
    }
}

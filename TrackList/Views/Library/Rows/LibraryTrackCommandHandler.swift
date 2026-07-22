import Foundation

/// Выполняет команды строки фонотеки, не смешивая их с UI.
@MainActor
struct LibraryTrackCommandHandler {
    let sheetManager: SheetManager
    let playbackHandler: LibraryTrackPlaybackHandler
    let presentationHandler: LibraryTrackPresentationHandler
    let cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler
    let onToggleSelection: () -> Void
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void

    /// Выполняет действие строки.
    func handle(_ action: LibraryTrackAction) {
        switch action {
        case .tapRow(let track, let context):
            playbackHandler.handleTap(track: track, context: context)
        case .tapArtwork(let track):
            sheetManager.present(.trackDetail(track))
        case .addToPlayer(let trackId):
            addToPlayer(trackId: trackId)
        case .addToTrackList(let track):
            sheetManager.presentAddToTrackList(for: track)
        case .moveToFolder(let track):
            SheetActionCoordinator.shared.handle(
                action: .moveToFolder,
                track: track,
                context: .library
            )
        case .editTags(let track):
            sheetManager.presentTrackDetailForEditing(track)
        case .rename(let trackId, let strategy):
            onRenameTrack(trackId, strategy)
        case .toggleSelection:
            onToggleSelection()
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

    /// Добавляет трек в плеер через общий executor приложения.
    private func addToPlayer(trackId: UUID) {
        Task {
            do {
                try await AppCommandExecutor.shared.addTrackToPlayer(
                    trackId: trackId
                )
            } catch let appError as AppError {
                ToastManager.shared.handle(appError)
            } catch {
                ToastManager.shared.handle(
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

import Foundation

/// Выполняет команды строки фонотеки, не смешивая их с UI.
@MainActor
struct LibraryTrackCommandHandler {
    let sheetManager: SheetManager
    let playbackHandler: LibraryTrackPlaybackHandler
    let presentationHandler: LibraryTrackPresentationHandler
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
            sheetManager.present(
                .addToTrackList(
                    AddToTrackListSheetData(
                        track: track,
                        sourceTrackListId: nil
                    )
                )
            )
        case .moveToFolder(let track):
            SheetActionCoordinator.shared.handle(
                action: .moveToFolder,
                track: track,
                context: .library
            )
        case .rename(let trackId, let strategy):
            onRenameTrack(trackId, strategy)
        case .toggleSelection:
            onToggleSelection()
        case .requestSnapshot(let trackId):
            presentationHandler.requestSnapshotIfNeeded(for: trackId)
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
                        message: "Не удалось добавить трек в плеер"
                    )
                )
            }
        }
    }
}

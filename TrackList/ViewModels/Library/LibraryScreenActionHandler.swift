//
//  LibraryScreenActionHandler.swift
//  TrackList
//
//  Обрабатывает действия контейнера фонотеки.
//  Здесь находятся переадресация reveal, навигация и показ toast-сообщений.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Foundation

@MainActor
final class LibraryScreenActionHandler {
    // MARK: - Dependencies

    private let navigationCoordinator: NavigationCoordinator
    private let musicLibraryManager: MusicLibraryManager
    private let trackRegistry: TrackRegistry
    private let toastPresenter: any ToastPresenting

    // MARK: - Init

    init(
        navigationCoordinator: NavigationCoordinator,
        musicLibraryManager: MusicLibraryManager,
        trackRegistry: TrackRegistry,
        toastPresenter: any ToastPresenting
    ) {
        self.navigationCoordinator = navigationCoordinator
        self.musicLibraryManager = musicLibraryManager
        self.trackRegistry = trackRegistry
        self.toastPresenter = toastPresenter
    }

    // MARK: - Handle

    func handle(_ action: LibraryScreenAction) {
        switch action {
        case .appeared:
            handlePendingShowTrack()
        case .libraryPathChanged(let libraryPath):
            navigationCoordinator.libraryPath = libraryPath
        case .revealHandled(let requestId):
            navigationCoordinator.clearRevealRequest(requestId: requestId)
        case .folderMissingAppeared:
            toastPresenter.handle(.folderNotFound)
        }
    }

    // MARK: - Private

    private func handlePendingShowTrack() {
        guard let trackId = navigationCoordinator.consumePendingShowTrackId() else { return }

        Task { @MainActor in
            guard let entry = await trackRegistry.entry(for: trackId) else {
                toastPresenter.handle(.showInLibraryTargetMissing)
                return
            }

            let folderId = entry.folderId

            guard musicLibraryManager.folder(for: folderId) != nil else {
                toastPresenter.handle(.folderNotFound)
                return
            }

            navigationCoordinator.setPendingRevealRequest(
                folderId: folderId,
                targetTrackId: trackId
            )
            navigationCoordinator.openFolder(folderId)
        }
    }
}

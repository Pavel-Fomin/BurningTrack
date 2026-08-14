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
    // MARK: - Зависимости

    private let navigationCoordinator: NavigationCoordinator
    private let musicLibraryManager: MusicLibraryManager
    private let trackRegistry: TrackRegistry
    private let toastPresenter: any ToastPresenting

    // MARK: - Инициализация

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

    // MARK: - Обработка

    func handle(_ action: LibraryScreenAction) {
        switch action {
        case .appeared:
            handlePendingShowInLibraryRequest()
        case .collectionRootItemSelected(let item):
            handleCollectionRootItemSelected(item)
        case .collectionValueSelected(let value):
            navigationCoordinator.pushCollectionValue(
                category: value.category,
                value: value.rawValue,
                artistKey: value.category == .albums ? value.artist : nil
            )
        case .libraryPathChanged(let libraryPath):
            navigationCoordinator.libraryPath = libraryPath
        case .revealHandled(let requestId):
            navigationCoordinator.clearRevealRequest(requestId: requestId)
        case .folderMissingAppeared:
            toastPresenter.handle(.folderNotFound)
        }
    }

    // MARK: - Приватное

    /// Открывает маршрут, соответствующий выбранной строке корня режима "Треки".
    private func handleCollectionRootItemSelected(_ item: LibraryCollectionRootItem) {
        switch item {
        case .allTracks:
            navigationCoordinator.openAllLibraryTracks()
        case .category(let category):
            navigationCoordinator.openCollectionCategory(category)
        }
    }

    /// Обрабатывает единый intent показа трека, уже содержащий его типизированный источник.
    private func handlePendingShowInLibraryRequest() {
        guard let request = navigationCoordinator.consumePendingShowInLibraryRequest() else {
            return
        }

        switch request.source {
        case .library:
            showLibraryTrack(request.trackId)

        case .purchasedITunes:
            navigationCoordinator.setPendingRevealRequest(
                destination: .purchasedITunes,
                targetTrackId: request.trackId
            )
            navigationCoordinator.openPurchasedITunes()
        }
    }

    /// Находит папку обычного трека и передаёт общий reveal-механизм в её destination.
    private func showLibraryTrack(_ trackId: UUID) {
        Task { @MainActor in
            guard let entry = await trackRegistry.entry(for: trackId) else {
                toastPresenter.handle(.showInLibraryTargetMissing)
                return
            }

            guard let folderId = entry.folderId else {
                toastPresenter.handle(.showInLibraryTargetMissing)
                return
            }

            guard musicLibraryManager.folder(for: folderId) != nil else {
                toastPresenter.handle(.folderNotFound)
                return
            }

            navigationCoordinator.setPendingRevealRequest(
                destination: .folder(folderId),
                targetTrackId: trackId
            )
            navigationCoordinator.openFolder(folderId)
        }
    }
}

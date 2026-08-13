// "LibraryTrackCommandHandlerTests.swift"
// TrackList
// Контракты typed-действий строк фонотеки.
// Created by Pavel Fomin on 13.08.2026.

import Combine
import Foundation
import UIKit
import XCTest
@testable import TrackList

/// Проверяет, что недоступная строка фонотеки остаётся presentation-намерением.
@MainActor
final class LibraryTrackCommandHandlerTests: XCTestCase {

    /// Недоступная строка показывает один Toast и не запускает playback или selection-flow.
    func testUnavailableTrackRoutesToToastWithoutPlaybackOrSelection() {
        let toastPresenter = LibraryUnavailableToastPresenterSpy()
        let playbackController = LibraryUnavailablePlaybackControllerSpy()
        var selectionToggleCount = 0
        let handler = makeHandler(
            toastPresenter: toastPresenter,
            playbackController: playbackController,
            onToggleSelection: {
                selectionToggleCount += 1
            }
        )
        let track = makeTrack(title: "Unavailable")

        handler.handle(.unavailableTrackTapped(track: track))

        XCTAssertEqual(toastPresenter.events, [.trackUnavailable(title: "Unavailable")])
        XCTAssertTrue(playbackController.playedTrackIds.isEmpty)
        XCTAssertEqual(playbackController.togglePlayPauseCount, 0)
        XCTAssertEqual(selectionToggleCount, 0)
    }

    /// Собирает handler с управляемыми зависимостями, не обращаясь к production ToastManager.
    private func makeHandler(
        toastPresenter: LibraryUnavailableToastPresenterSpy,
        playbackController: LibraryUnavailablePlaybackControllerSpy,
        onToggleSelection: @escaping () -> Void
    ) -> LibraryTrackCommandHandler {
        let playbackState = LibraryUnavailablePlaybackStateProviderSpy()
        let cloudController = LibraryCloudAvailabilityScreenController(
            availabilityController: CloudTrackAvailabilityController(
                manager: LibraryUnavailableCloudManagerSpy()
            )
        )

        return LibraryTrackCommandHandler(
            sheetManager: SheetManager(),
            playbackHandler: LibraryTrackPlaybackHandler(
                playbackStateProvider: playbackState,
                playbackController: playbackController
            ),
            presentationHandler: LibraryTrackPresentationHandler(
                metadataProvider: LibraryUnavailableMetadataProviderSpy()
            ),
            cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler(
                controller: cloudController
            ),
            collectionNavigationHandler: LibraryUnavailableCollectionNavigatorSpy(),
            trackShareActionHandler: TrackShareActionHandler(
                preparationService: TrackSharePreparationService(),
                viewControllerProvider: LibraryUnavailableViewControllerProviderSpy(),
                toastPresenter: toastPresenter
            ),
            commandExecutor: LibraryUnavailablePlayerAddingSpy(),
            toastManager: toastPresenter,
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: LibraryUnavailableFavoritesServiceSpy()
            ),
            onToggleSelection: { _ in
                onToggleSelection()
            },
            onRenameTrack: { _, _ in }
        )
    }

    /// Создаёт недоступный трек фонотеки для строки.
    private func makeTrack(title: String) -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/Unavailable.flac"),
            title: title,
            artist: "Artist",
            duration: 100,
            addedDate: Date()
        )
    }
}

/// Фиксирует presentation-события без глобального ToastManager.
@MainActor
private final class LibraryUnavailableToastPresenterSpy: ToastPresenting {
    private(set) var errors: [AppError] = []
    private(set) var events: [ToastEvent] = []

    func handle(_ error: AppError) {
        errors.append(error)
    }

    func handle(_ event: ToastEvent, duration: TimeInterval) {
        events.append(event)
    }
}

/// Фиксирует playback-команды, которые недоступная строка не должна отправлять.
@MainActor
private final class LibraryUnavailablePlaybackControllerSpy: TrackPlaybackControlling {
    private(set) var togglePlayPauseCount = 0
    private(set) var playedTrackIds: [UUID] = []

    func togglePlayPause() {
        togglePlayPauseCount += 1
    }

    func play(
        track: any TrackDisplayable,
        context: [any TrackDisplayable],
        source: PlaybackContextSource
    ) {
        playedTrackIds.append(track.trackId)
    }
}

/// Предоставляет неизменяемое playback-состояние для неиспользуемой ветви handler-а.
@MainActor
private final class LibraryUnavailablePlaybackStateProviderSpy: PlaybackStateProviding {
    private let subject = CurrentValueSubject<PlaybackStateSnapshot, Never>(
        PlaybackStateSnapshot(
            currentDisplayableId: nil,
            currentTrackId: nil,
            currentContext: nil,
            currentContextSource: nil,
            isPlaying: false
        )
    )

    var playbackState: PlaybackStateSnapshot { subject.value }
    var currentDisplayableId: UUID? { nil }
    var currentTrackId: UUID? { nil }
    var currentContext: PlaybackContext? { nil }
    var currentContextSource: PlaybackContextSource? { nil }
    var isPlaying: Bool { false }
    var playbackStatePublisher: AnyPublisher<PlaybackStateSnapshot, Never> {
        subject.eraseToAnyPublisher()
    }
}

/// Возвращает пустые metadata, поскольку unavailable-route их не читает.
@MainActor
private final class LibraryUnavailableMetadataProviderSpy: TrackMetadataProviding {
    func snapshot(for trackId: UUID) -> TrackRuntimeSnapshot? { nil }
    func collectionNavigationTarget(for trackId: UUID) -> TrackCollectionNavigationTarget? { nil }
    func requestSnapshotIfNeeded(for trackId: UUID) {}
}

/// Не открывает экран коллекции в проверке недоступной строки.
@MainActor
private final class LibraryUnavailableCollectionNavigatorSpy: TrackCollectionIdentifierNavigating {
    func openArtist(trackId: UUID) {}
    func openAlbum(trackId: UUID) {}
}

/// Не выполняет добавление в очередь в проверке presentation-намерения.
private actor LibraryUnavailablePlayerAddingSpy: LibraryTrackPlayerAdding {
    func addTrackToPlayer(trackId: UUID) async throws -> TrackAddedToPlayerSuccess {
        throw LibraryUnavailableTestError.unexpectedCall
    }
}

/// Не выполняет iCloud-операции в изолированной проверке presentation-route.
private actor LibraryUnavailableCloudManagerSpy: CloudTrackAvailabilityManaging {
    func availabilityStates(
        for trackIds: [UUID]
    ) async -> [UUID: CloudTrackAvailabilityState] { [:] }

    func retryDownloading(trackId: UUID) async -> CloudTrackAvailabilityState? { nil }
}

/// Не предоставляет UIKit presenter, потому что share-flow в тесте не запускается.
@MainActor
private final class LibraryUnavailableViewControllerProviderSpy: ViewControllerProviding {
    func topViewController() -> UIViewController? { nil }
}

/// Реализует неиспользуемые Favorites-команды без persistent storage.
@MainActor
private final class LibraryUnavailableFavoritesServiceSpy: FavoritesServicing {
    func loadFavoriteTrackIds() throws -> Set<UUID> { [] }
    func isFavorite(trackId: UUID) throws -> Bool { false }
    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult { .added }
    func remove(trackId: UUID) throws -> FavoritesMutationResult { .removed }
    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        .unchanged(isFavorite: false)
    }
}

/// Обозначает неожиданное попадание в не относящуюся к тесту доменную ветвь.
private enum LibraryUnavailableTestError: Error {
    case unexpectedCall
}

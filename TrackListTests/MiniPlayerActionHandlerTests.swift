//
//  MiniPlayerActionHandlerTests.swift
//  TrackListTests
//
//  Проверки маршрутизации действий MiniPlayer.
//
//  Created by Pavel Fomin on 10.08.2026.
//

import Combine
import XCTest
@testable import TrackList

@MainActor
final class MiniPlayerActionHandlerTests: XCTestCase {

    /// Playback-команды уходят только в узкий controlling capability.
    func testPlaybackActionsRouteToPlaybackController() {
        let harness = makeHarness()

        harness.actionHandler.handle(.playPause)
        harness.actionHandler.handle(.playPrevious)
        harness.actionHandler.handle(.playNext)
        harness.actionHandler.handle(.seek(42))
        harness.actionHandler.handle(.toggleShuffle)
        harness.actionHandler.handle(.toggleRepeatAll)
        harness.actionHandler.handle(.toggleRepeatOne)

        XCTAssertEqual(harness.playbackController.togglePlayPauseCount, 1)
        XCTAssertEqual(harness.playbackController.playPreviousCount, 1)
        XCTAssertEqual(harness.playbackController.playNextCount, 1)
        XCTAssertEqual(harness.playbackController.seekedTimes, [42])
        XCTAssertEqual(harness.playbackController.toggleShuffleCount, 1)
        XCTAssertEqual(harness.playbackController.toggleRepeatAllCount, 1)
        XCTAssertEqual(harness.playbackController.toggleRepeatOneCount, 1)
    }

    /// Favorite использует существующий общий handler и не публикует собственное optimistic-состояние.
    func testToggleFavoriteRoutesToExistingFavoriteFlow() {
        let harness = makeHarness()

        harness.actionHandler.handle(.toggleFavorite)

        XCTAssertEqual(harness.favoritesService.toggledTrackIds, [harness.track.trackId])
    }

    /// Маршрут фонотеки выполняется через внедрённую navigation capability.
    func testShowInLibraryRoutesEligibleLibraryTrack() {
        let harness = makeHarness()

        harness.actionHandler.handle(.showCurrentTrackInLibrary)

        XCTAssertEqual(harness.libraryRouter.shownTrackIds, [harness.track.trackId])
    }

    /// Handler повторно защищает navigation capability, если в него попадёт действие из error state вне SwiftUI View.
    func testShowInLibraryIsIgnoredForErrorState() {
        let track = makeLibraryTrack()
        let harness = makeHarness(currentTrack: track, miniPlayerState: .error)

        harness.actionHandler.handle(.showCurrentTrackInLibrary)

        XCTAssertEqual(harness.libraryRouter.shownTrackIds, [])
    }

    /// Значение expansion сохраняется handler-ом и не становится состоянием плеера.
    func testSetExpandedPersistsThroughSettingsCapability() {
        let harness = makeHarness()

        harness.actionHandler.handle(.setExpanded(true))

        XCTAssertTrue(harness.settingsManager.settings.internalSettings.isMiniPlayerExpanded)
    }

    /// Недоступные без текущего трека playback и favorite-команды не доходят до внешних capability.
    func testTrackActionsAreIgnoredWithoutCurrentTrack() {
        let harness = makeHarness(currentTrack: nil, miniPlayerState: .empty)

        harness.actionHandler.handle(.playPause)
        harness.actionHandler.handle(.seek(42))
        harness.actionHandler.handle(.toggleFavorite)
        harness.actionHandler.handle(.showCurrentTrackInLibrary)

        XCTAssertEqual(harness.playbackController.togglePlayPauseCount, 0)
        XCTAssertEqual(harness.playbackController.seekedTimes, [])
        XCTAssertEqual(harness.favoritesService.toggledTrackIds, [])
        XCTAssertEqual(harness.libraryRouter.shownTrackIds, [])
    }

    /// Собирает handler из узких тестовых capability без реального PlayerViewModel или singleton-ов.
    private func makeHarness(
        currentTrack: LibraryTrack? = nil,
        miniPlayerState: MiniPlayerState? = nil
    ) -> MiniPlayerActionHandlerHarness {
        let track = currentTrack ?? makeLibraryTrack()
        let state = miniPlayerState ?? makePlayingState(for: track)
        let playbackProvider = MiniPlayerPlaybackProviderSpy(
            currentTrack: currentTrack == nil && miniPlayerState == .empty ? nil : track,
            miniPlayerState: state
        )
        let playbackController = MiniPlayerPlaybackControllerSpy()
        let favoritesService = MiniPlayerFavoritesServiceSpy()
        let settingsManager = MiniPlayerSettingsManagerSpy()
        let libraryRouter = MiniPlayerLibraryRouterSpy()
        let actionHandler = MiniPlayerActionHandler(
            playbackProvider: playbackProvider,
            playbackController: playbackController,
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: favoritesService
            ),
            settingsManager: settingsManager,
            libraryRouter: libraryRouter
        )

        return MiniPlayerActionHandlerHarness(
            actionHandler: actionHandler,
            track: track,
            playbackController: playbackController,
            favoritesService: favoritesService,
            settingsManager: settingsManager,
            libraryRouter: libraryRouter
        )
    }

    /// Создаёт локальный трек, для которого доступен существующий маршрут фонотеки.
    private func makeLibraryTrack() -> LibraryTrack {
        LibraryTrack(
            id: UUID(),
            fileURL: URL(fileURLWithPath: "/tmp/MiniPlayer.m4a"),
            title: "Track",
            artist: "Artist",
            duration: 180,
            addedDate: Date()
        )
    }

    /// Создаёт playing state, соответствующий текущей display-модели capability.
    private func makePlayingState(for track: LibraryTrack) -> MiniPlayerState {
        .playing(
            staticState: MiniPlayerStaticState(
                trackId: track.trackId,
                title: track.title ?? track.fileName,
                artist: track.artist,
                artworkRequest: nil
            ),
            progressState: MiniPlayerProgressState(
                isPlaying: true,
                currentTime: 0,
                duration: track.duration
            )
        )
    }
}

/// Содержит связанные spy-capability одного focused-теста action flow.
@MainActor
private struct MiniPlayerActionHandlerHarness {
    let actionHandler: MiniPlayerActionHandler
    let track: LibraryTrack
    let playbackController: MiniPlayerPlaybackControllerSpy
    let favoritesService: MiniPlayerFavoritesServiceSpy
    let settingsManager: MiniPlayerSettingsManagerSpy
    let libraryRouter: MiniPlayerLibraryRouterSpy
}

/// Предоставляет handler-у только текущие playback-данные без полного PlayerViewModel.
@MainActor
private final class MiniPlayerPlaybackProviderSpy: MiniPlayerPlaybackProviding {
    var currentTrackDisplayable: (any TrackDisplayable)?
    var miniPlayerState: MiniPlayerState
    var waveformState: PlayerWaveformState = .unavailable
    var isCurrentTrackFavorite = false
    var playbackMode: PlaybackMode = .defaultValue

    init(
        currentTrack: (any TrackDisplayable)?,
        miniPlayerState: MiniPlayerState
    ) {
        currentTrackDisplayable = currentTrack
        self.miniPlayerState = miniPlayerState
    }
}

/// Фиксирует команды, которые handler передаёт в узкий playback capability.
@MainActor
private final class MiniPlayerPlaybackControllerSpy: MiniPlayerPlaybackControlling {
    private(set) var togglePlayPauseCount = 0
    private(set) var playPreviousCount = 0
    private(set) var playNextCount = 0
    private(set) var seekedTimes: [TimeInterval] = []
    private(set) var toggleShuffleCount = 0
    private(set) var toggleRepeatAllCount = 0
    private(set) var toggleRepeatOneCount = 0

    func togglePlayPause() {
        togglePlayPauseCount += 1
    }

    func playPreviousTrack() {
        playPreviousCount += 1
    }

    func playNextTrack() {
        playNextCount += 1
    }

    func seek(to time: TimeInterval) {
        seekedTimes.append(time)
    }

    func toggleShuffle() {
        toggleShuffleCount += 1
    }

    func toggleRepeatAll() {
        toggleRepeatAllCount += 1
    }

    func toggleRepeatOne() {
        toggleRepeatOneCount += 1
    }
}

/// Фиксирует вход в существующий доменный flow «Избранного».
@MainActor
private final class MiniPlayerFavoritesServiceSpy: FavoritesServicing {
    private(set) var toggledTrackIds: [UUID] = []

    func loadFavoriteTrackIds() throws -> Set<UUID> {
        []
    }

    func isFavorite(trackId: UUID) throws -> Bool {
        false
    }

    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        .added
    }

    func remove(trackId: UUID) throws -> FavoritesMutationResult {
        .removed
    }

    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        toggledTrackIds.append(track.trackId)
        return .added
    }
}

/// Сохраняет только настройку expansion для проверки action flow.
@MainActor
private final class MiniPlayerSettingsManagerSpy: SettingsManaging {
    @Published private var currentSettings = AppSettings.defaultValue

    var settings: AppSettings {
        currentSettings
    }

    var settingsPublisher: Published<AppSettings>.Publisher {
        $currentSettings
    }

    func setTagReadingEnabled(_ value: Bool) {}
    func setTrackListMembershipVisible(_ value: Bool) {}
    func setFileFormatVisible(_ value: Bool) {}
    func setPurchasedITunesSourceVisible(_ value: Bool) {}

    func setMiniPlayerExpanded(_ value: Bool) {
        currentSettings.internalSettings.isMiniPlayerExpanded = value
    }

    func setLibraryRootDisplayMode(_ mode: LibraryRootDisplayMode) throws {}
    func setLibraryTrackSortMode(_ mode: LibraryTrackSortMode) throws {}
    func setTrackListsSortMode(_ mode: TrackListsSortMode?) throws {}

    func applyPersistedTrackListsSortMode(_: TrackListsSortMode?) {
        // Этот test double не хранит состояние сортировки треклистов.
    }
}

/// Фиксирует вызов navigation capability без SheetActionCoordinator.shared.
@MainActor
private final class MiniPlayerLibraryRouterSpy: MiniPlayerLibraryRouting {
    private(set) var shownTrackIds: [UUID] = []

    func showInLibrary(_ track: any TrackDisplayable) {
        shownTrackIds.append(track.trackId)
    }
}

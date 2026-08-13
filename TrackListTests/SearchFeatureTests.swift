//
//  SearchFeatureTests.swift
//  TrackList
//
//  Проверки action, состояния и presentation-слоя feature Search.
//  Created by Pavel Fomin on 11.08.2026.
//

import Combine
import UIKit
import XCTest
@testable import TrackList

@MainActor
final class SearchActionHandlerTests: XCTestCase {

    /// Playback-действие текущей строки переключает воспроизведение, а другой строки запускает новый контекст поиска.
    func testPlayTrackRoutesToInjectedPlaybackCapability() {
        let currentTrack = makeSearchTrack(title: "Current")
        let nextTrack = makeSearchTrack(title: "Next")
        let harness = makeActionHandlerHarness(currentTrackId: currentTrack.trackId)

        harness.actionHandler.handle(.playTrack(currentTrack))
        harness.actionHandler.handle(.playTrack(nextTrack))

        XCTAssertEqual(harness.playbackController.togglePlayPauseCount, 1)
        XCTAssertEqual(harness.playbackController.playedTrackIds, [nextTrack.trackId])
        XCTAssertEqual(harness.playbackController.playedContexts, [[nextTrack.trackId]])
        XCTAssertEqual(harness.playbackController.playedSources, [.playerQueue])
    }

    /// Favorite передаётся существующему общему handler-у и не меняет состояние Search оптимистично.
    func testToggleFavoriteRoutesToInjectedFavoriteHandler() {
        let track = makeSearchTrack(title: "Favorite")
        let harness = makeActionHandlerHarness(currentTrackId: nil)

        harness.actionHandler.handle(.toggleFavorite(track))

        XCTAssertEqual(harness.favoritesService.toggledTrackIds, [track.trackId])
    }

    /// Недоступная строка сообщает feature action и не запускает playback.
    func testUnavailableTrackRoutesToToastWithoutPlayback() {
        let track = makeSearchTrack(fileName: "Unavailable.m4a", title: "Unavailable")
        let harness = makeActionHandlerHarness(currentTrackId: nil)

        harness.actionHandler.handle(.unavailableTrackTapped(track))

        XCTAssertEqual(harness.toastPresenter.events, [.trackUnavailable(title: "Unavailable")])
        XCTAssertTrue(harness.playbackController.playedTrackIds.isEmpty)
        XCTAssertEqual(harness.playbackController.togglePlayPauseCount, 0)
    }

    /// Собирает SearchActionHandler с наблюдаемыми capability без PlayerViewModel.
    private func makeActionHandlerHarness(
        currentTrackId: UUID?
    ) -> SearchActionHandlerHarness {
        let playbackStateProvider = SearchPlaybackStateProviderSpy(
            currentTrackId: currentTrackId
        )
        let playbackController = SearchPlaybackControllerSpy()
        let toastPresenter = SearchToastPresenterSpy()
        let sheetManager = SheetManager()
        let favoritesService = SearchFavoritesServiceSpy()
        let viewModel = makeSearchViewModel(
            searchService: SearchViewModelSearchServiceSpy(results: .empty),
            playbackStateProvider: playbackStateProvider,
            toastPresenter: toastPresenter
        )
        let actionHandler = SearchActionHandler(
            viewModel: viewModel,
            playbackStateProvider: playbackStateProvider,
            playbackController: playbackController,
            navigationCoordinator: .shared,
            sheetManager: sheetManager,
            fileRenamer: TrackFileRenameActionHandler(
                fileBusyChecker: SearchTrackFileBusyCheckerSpy(),
                sheetManager: sheetManager,
                commandExecutor: .shared,
                toastManager: ToastManager(),
                proposalBuilder: FileRenameProposalBuilder()
            ),
            favoriteActionHandler: FavoriteTrackActionHandler(
                favoritesService: favoritesService
            ),
            trackShareActionHandler: TrackShareActionHandler(
                preparationService: TrackSharePreparationService(),
                viewControllerProvider: SearchViewControllerProviderSpy(),
                toastPresenter: toastPresenter
            ),
            commandExecutor: .shared,
            commandToastPresenter: AppCommandToastPresenter(
                toastPresenter: toastPresenter
            ),
            toastPresenter: toastPresenter
        )

        return SearchActionHandlerHarness(
            actionHandler: actionHandler,
            playbackController: playbackController,
            favoritesService: favoritesService,
            toastPresenter: toastPresenter
        )
    }
}

@MainActor
final class SearchViewModelTests: XCTestCase {

    /// Непустой запрос передаётся в сервис в нормализованном виде и публикует готовый state для View.
    func testUpdateQueryPublishesResultsFromSearchService() async {
        let track = makeSearchTrack(title: "Alpha")
        let service = SearchViewModelSearchServiceSpy(
            results: SearchResults(
                folders: [],
                trackLists: [],
                tracks: [track]
            )
        )
        let viewModel = makeSearchViewModel(searchService: service)

        viewModel.updateQuery("  Alpha  ")
        await waitUntil {
            viewModel.state.contentState == .results
        }

        let receivedQueries = await service.queries()

        XCTAssertEqual(receivedQueries, ["Alpha"])
        XCTAssertEqual(viewModel.state.query, "  Alpha  ")
        XCTAssertEqual(viewModel.state.tracks.map(\.id), [track.trackId])
        XCTAssertEqual(viewModel.state.tracks.first?.title, "Alpha")
    }

    /// Очистка запроса отменяет поисковый контекст и возвращает состояние пустой строки.
    func testClearQueryRestoresEmptySearchState() async {
        let service = SearchViewModelSearchServiceSpy(
            results: SearchResults(
                folders: [],
                trackLists: [],
                tracks: [makeSearchTrack(title: "Alpha")]
            )
        )
        let viewModel = makeSearchViewModel(searchService: service)

        viewModel.updateQuery("Alpha")
        await waitUntil {
            viewModel.state.contentState == .results
        }
        viewModel.clearQuery()

        XCTAssertEqual(viewModel.state.contentState, .emptyQuery)
        XCTAssertEqual(viewModel.state.query, "")
        XCTAssertTrue(viewModel.state.tracks.isEmpty)
        XCTAssertTrue(viewModel.state.trackFilterChips.isEmpty)
    }
}

@MainActor
final class SearchPresenterTests: XCTestCase {

    /// Presenter сортирует строки и готовит единые favorite и playback признаки без логики во View.
    func testResultsPrepareSortedTrackRowsWithFavoriteAndPlaybackState() {
        let playingTrack = makeSearchTrack(
            fileName: "Zulu.m4a",
            title: "Zulu",
            artist: "Artist Z"
        )
        let favoriteTrack = makeSearchTrack(
            fileName: "Alpha.m4a",
            title: "Alpha",
            artist: "Artist A"
        )
        let presenter = SearchPresenter()

        let state = presenter.results(
            query: "a",
            results: SearchResults(
                folders: [],
                trackLists: [],
                tracks: [playingTrack, favoriteTrack]
            ),
            selectedTrackFilterField: nil,
            selectedSortMode: .titleAsc,
            snapshotsByTrackId: [:],
            favoriteTrackIds: [favoriteTrack.trackId],
            playbackState: SearchPlaybackStateProviderSpy(
                currentTrackId: playingTrack.trackId,
                isPlaying: true
            ).playbackState,
            displaySettings: SearchTrackDisplaySettings(
                shouldShowTags: true,
                shouldShowTrackListMembership: true,
                shouldShowFileFormat: true
            )
        )

        XCTAssertEqual(state.contentState, .results)
        XCTAssertEqual(state.tracks.map(\.title), ["Alpha", "Zulu"])
        XCTAssertTrue(state.tracks[0].isFavorite)
        XCTAssertFalse(state.tracks[0].isCurrent)
        XCTAssertTrue(state.tracks[1].isCurrent)
        XCTAssertTrue(state.tracks[1].isPlaying)
        XCTAssertEqual(state.tracks.map(\.showsFileFormat), [true, true])
    }
}

/// Связанные зависимости одного теста SearchActionHandler.
@MainActor
private struct SearchActionHandlerHarness {
    let actionHandler: SearchActionHandler
    let playbackController: SearchPlaybackControllerSpy
    let favoritesService: SearchFavoritesServiceSpy
    let toastPresenter: SearchToastPresenterSpy
}

/// Возвращает подготовленный результат поиска без доступа к SQLite-фонотеке.
private func makeSearchTrack(
    id: UUID = UUID(),
    fileName: String = "Track.m4a",
    title: String? = nil,
    artist: String? = nil
) -> SearchTrackResult {
    SearchTrackResult(
        id: id,
        fileName: fileName,
        fileDate: Date(timeIntervalSince1970: 0),
        relativePath: fileName,
        folderId: nil,
        rootFolderId: nil,
        folderTitle: "Library",
        libraryPath: "Library/\(fileName)",
        title: title,
        artist: artist,
        duration: 180,
        album: nil,
        year: nil,
        label: nil,
        genre: nil,
        comment: nil,
        trackListMemberships: [],
        isAvailable: true
    )
}

/// Создаёт ViewModel с локальными capability, не подменяя runtime pipeline Search.
@MainActor
private func makeSearchViewModel(
    searchService: any SearchServicing,
    playbackStateProvider: (any PlaybackStateProviding)? = nil,
    toastPresenter: (any ToastPresenting)? = nil
) -> SearchViewModel {
    // MainActor создаёт test capability здесь, а не в default-аргументе неisolated-сигнатуры.
    let resolvedPlaybackStateProvider = playbackStateProvider
        ?? SearchPlaybackStateProviderSpy()
    let resolvedToastPresenter = toastPresenter
        ?? SearchToastPresenterSpy()

    return SearchViewModel(
        searchService: searchService,
        runtimeController: LibraryTrackRuntimeController(),
        settingsManager: SearchSettingsManagerSpy(),
        favoriteTrackIdsProvider: SearchFavoriteTrackIdsProviderSpy(),
        playbackStateProvider: resolvedPlaybackStateProvider,
        toastPresenter: resolvedToastPresenter,
        presenter: SearchPresenter()
    )
}

/// Возвращает детерминированную выдачу и фиксирует нормализованные запросы ViewModel.
private actor SearchViewModelSearchServiceSpy: SearchServicing {
    private let results: SearchResults
    private(set) var receivedQueries: [String] = []

    init(results: SearchResults) {
        self.results = results
    }

    func search(query: String) async throws -> SearchResults {
        receivedQueries.append(query)
        return results
    }

    /// Возвращает зафиксированные запросы за пределы actor-изоляции spy.
    func queries() -> [String] {
        receivedQueries
    }
}

/// Предоставляет неизменяемые presentation-настройки для тестовой выдачи.
@MainActor
private final class SearchSettingsManagerSpy: SettingsManaging {
    @Published private var currentSettings = AppSettings.defaultValue

    var settings: AppSettings {
        currentSettings
    }

    var settingsPublisher: Published<AppSettings>.Publisher {
        $currentSettings
    }

    func setTagReadingEnabled(_: Bool) {}
    func setTrackListMembershipVisible(_: Bool) {}
    func setFileFormatVisible(_: Bool) {}
    func setPurchasedITunesSourceVisible(_: Bool) {}
    func setMiniPlayerExpanded(_: Bool) {}
    func setLibraryRootDisplayMode(_: LibraryRootDisplayMode) throws {}
    func setLibraryTrackSortMode(_: LibraryTrackSortMode) throws {}
    func setTrackListsSortMode(_: TrackListsSortMode?) throws {}

    func applyPersistedTrackListsSortMode(_: TrackListsSortMode?) {
        // Этот test double не хранит состояние сортировки треклистов.
    }
}

/// Предоставляет подтверждённое пустое состояние «Избранного» для ViewModel Search.
@MainActor
private final class SearchFavoriteTrackIdsProviderSpy: FavoriteTrackIdsProviding {
    @Published private var currentIds = Set<UUID>()

    var favoriteTrackIds: Set<UUID> {
        currentIds
    }

    var favoriteTrackIdsPublisher: AnyPublisher<Set<UUID>, Never> {
        $currentIds.eraseToAnyPublisher()
    }
}

/// Хранит наблюдаемое playback-состояние без зависимости от PlayerViewModel.
@MainActor
private final class SearchPlaybackStateProviderSpy: PlaybackStateProviding {
    @Published private var currentState: PlaybackStateSnapshot

    init(
        currentTrackId: UUID? = nil,
        isPlaying: Bool = false
    ) {
        currentState = PlaybackStateSnapshot(
            currentDisplayableId: currentTrackId,
            currentTrackId: currentTrackId,
            currentContext: nil,
            currentContextSource: nil,
            isPlaying: isPlaying
        )
    }

    var playbackState: PlaybackStateSnapshot {
        currentState
    }

    var currentDisplayableId: UUID? {
        currentState.currentDisplayableId
    }

    var currentTrackId: UUID? {
        currentState.currentTrackId
    }

    var currentContext: PlaybackContext? {
        currentState.currentContext
    }

    var currentContextSource: PlaybackContextSource? {
        currentState.currentContextSource
    }

    var isPlaying: Bool {
        currentState.isPlaying
    }

    var playbackStatePublisher: AnyPublisher<PlaybackStateSnapshot, Never> {
        $currentState.eraseToAnyPublisher()
    }
}

/// Фиксирует команды playback, отправленные SearchActionHandler-ом.
@MainActor
private final class SearchPlaybackControllerSpy: TrackPlaybackControlling {
    private(set) var togglePlayPauseCount = 0
    private(set) var playedTrackIds: [UUID] = []
    private(set) var playedContexts: [[UUID]] = []
    private(set) var playedSources: [PlaybackContextSource] = []

    func togglePlayPause() {
        togglePlayPauseCount += 1
    }

    func play(
        track: any TrackDisplayable,
        context: [any TrackDisplayable],
        source: PlaybackContextSource
    ) {
        playedTrackIds.append(track.trackId)
        playedContexts.append(context.map(\.trackId))
        playedSources.append(source)
    }
}

/// Фиксирует вызовы общего доменного сценария «Избранного».
@MainActor
private final class SearchFavoritesServiceSpy: FavoritesServicing {
    private(set) var toggledTrackIds: [UUID] = []

    func loadFavoriteTrackIds() throws -> Set<UUID> {
        []
    }

    func isFavorite(trackId _: UUID) throws -> Bool {
        false
    }

    func add(_: FavoriteTrackInput) throws -> FavoritesMutationResult {
        .added
    }

    func remove(trackId _: UUID) throws -> FavoritesMutationResult {
        .removed
    }

    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        toggledTrackIds.append(track.trackId)
        return .added
    }
}

/// Не показывает UI, но сохраняет факт пользовательского сообщения.
@MainActor
private final class SearchToastPresenterSpy: ToastPresenting {
    private(set) var events: [ToastEvent] = []
    private(set) var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration _: TimeInterval) {
        events.append(event)
    }

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

/// Не удерживает файл в тестах ActionHandler-а.
@MainActor
private final class SearchTrackFileBusyCheckerSpy: TrackFileBusyChecking {
    func isTrackFileBusy(trackId _: UUID) -> Bool {
        false
    }
}

/// Исключает presentation UIKit при сборке независимого TrackShareActionHandler.
@MainActor
private final class SearchViewControllerProviderSpy: ViewControllerProviding {
    func topViewController() -> UIViewController? {
        nil
    }
}

extension SearchViewModelTests {
    /// Ожидает короткую асинхронную цепочку Search без привязки к длительности устройства.
    fileprivate func waitUntil(
        _ condition: @escaping () -> Bool
    ) async {
        for _ in 0..<100 {
            if condition() {
                return
            }

            await Task.yield()
        }

        XCTFail("Не выполнено ожидаемое асинхронное условие Search")
    }
}

//
//  LibraryScreenViewModel.swift
//  TrackList
//
//  ViewModel контейнера фонотеки.
//  Наблюдает координатор и менеджер, публикует готовое состояние и делегирует действия.
//
//  Created by Pavel Fomin on 20.06.2026.
//
import Combine
import Foundation

@MainActor
final class LibraryScreenViewModel: ObservableObject {
    // MARK: - Output

    @Published private(set) var screenState: LibraryScreenState
    /// Готовые строки корня режима "Треки"; nil-счётчик означает продолжающуюся загрузку.
    @Published private(set) var collectionRootItems: [LibraryCollectionRootItemState]

    // MARK: - Dependencies

    private let navigationCoordinator: NavigationCoordinator
    private let musicLibraryManager: MusicLibraryManager
    private let stateBuilder: LibraryScreenStateBuilder
    private let actionHandler: LibraryScreenActionHandler
    /// Provider строит корневые строки из того же набора значений, что и подкатегории.
    private let collectionRootItemsProvider: any LibraryCollectionRootItemsProvider
    /// Источник существующих событий изменения треков и metadata.
    private let trackEventProvider: any LibraryTrackEventProvider

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    /// Отменяет устаревшую загрузку перед началом нового общего снимка.
    private var collectionRootRefreshTask: Task<Void, Never>?
    /// Не даёт отменённой задаче очистить состояние уже запущенной загрузки.
    private var collectionRootRefreshGeneration = 0

    // MARK: - Init

    init(
        navigationCoordinator: NavigationCoordinator,
        musicLibraryManager: MusicLibraryManager,
        stateBuilder: LibraryScreenStateBuilder,
        actionHandler: LibraryScreenActionHandler,
        collectionRootItemsProvider: (any LibraryCollectionRootItemsProvider)? = nil,
        trackEventProvider: (any LibraryTrackEventProvider)? = nil
    ) {
        self.navigationCoordinator = navigationCoordinator
        self.musicLibraryManager = musicLibraryManager
        self.stateBuilder = stateBuilder
        self.actionHandler = actionHandler
        self.collectionRootItemsProvider = collectionRootItemsProvider
            ?? DefaultLibraryCollectionValuesProvider()
        self.trackEventProvider = trackEventProvider
            ?? NotificationLibraryTrackEventProvider()
        self.screenState = stateBuilder.build(
            navigationCoordinator: navigationCoordinator,
            musicLibraryManager: musicLibraryManager
        )
        self.collectionRootItems = Self.loadingCollectionRootItems

        observeDependencies()
    }

    // MARK: - Actions

    func handle(_ action: LibraryScreenAction) {
        actionHandler.handle(action)
        refreshState()
    }

    /// Запускает чтение корневых счётчиков при появлении корня и после возврата из destination-экрана.
    func refreshCollectionRootItems() {
        collectionRootRefreshGeneration += 1
        let generation = collectionRootRefreshGeneration

        collectionRootRefreshTask?.cancel()
        collectionRootItems = Self.loadingCollectionRootItems

        collectionRootRefreshTask = Task { [weak self] in
            guard let self else { return }

            let items = await collectionRootItemsProvider.rootItemsState()
            guard Task.isCancelled == false else { return }
            guard collectionRootRefreshGeneration == generation else { return }

            collectionRootItems = items
            collectionRootRefreshTask = nil
        }
    }

    // MARK: - Private

    /// Строит шесть строк корня без ложных нулей до завершения первого чтения SQLite.
    private static let loadingCollectionRootItems = LibraryCollectionRootItem.rootItems.map {
        LibraryCollectionRootItemState(item: $0, count: nil)
    }

    private func refreshState() {
        screenState = stateBuilder.build(
            navigationCoordinator: navigationCoordinator,
            musicLibraryManager: musicLibraryManager
        )
    }

    private func observeDependencies() {
        navigationCoordinator.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshState()
                }
            }
            .store(in: &cancellables)

        musicLibraryManager.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshState()
                    self?.refreshCollectionRootItems()
                }
            }
            .store(in: &cancellables)

        trackEventProvider.trackDidUpdate
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshCollectionRootItems()
                }
            }
            .store(in: &cancellables)

        trackEventProvider.trackBatchDidUpdate
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshCollectionRootItems()
                }
            }
            .store(in: &cancellables)
    }
}

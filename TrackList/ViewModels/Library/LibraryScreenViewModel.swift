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
    /// Текущая загрузка корневого снимка; одновременно выполняется только одна задача.
    private var collectionRootRefreshTask: Task<Void, Never>?
    /// Признак устаревшего снимка корневых счётчиков.
    private var collectionRootItemsNeedsRefresh = true
    /// Запоминает изменение, пришедшее во время чтения текущего снимка.
    private var collectionRootRefreshRequestedWhileLoading = false
    /// Корневой список режима "Треки" сейчас виден пользователю.
    private var isCollectionRootVisible = false

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

    /// Сообщает ViewModel, виден ли корневой список режима "Треки".
    func setCollectionRootVisibility(_ isVisible: Bool) {
        isCollectionRootVisible = isVisible

        guard isVisible else { return }
        refreshCollectionRootItems()
    }

    /// Запускает чтение корневых счётчиков при появлении корня и после возврата из destination-экрана.
    func refreshCollectionRootItems() {
        guard isCollectionRootVisible else { return }
        guard collectionRootItemsNeedsRefresh else { return }
        guard collectionRootRefreshTask == nil else { return }

        collectionRootItemsNeedsRefresh = false

        // После первой успешной загрузки сохраняем старые счётчики до готовности нового снимка,
        // чтобы при переключении режима не было лишнего мигания и повторной перестройки списка.
        if collectionRootItems.contains(where: { $0.count != nil }) == false {
            collectionRootItems = Self.loadingCollectionRootItems
        }

        let provider = collectionRootItemsProvider
        collectionRootRefreshTask = Task { [weak self] in
            let items = await provider.rootItemsState()
            guard let self else { return }

            guard Task.isCancelled == false else {
                collectionRootItemsNeedsRefresh = true
                collectionRootRefreshTask = nil
                return
            }

            let shouldRefreshAgain = collectionRootRefreshRequestedWhileLoading
            if shouldRefreshAgain == false {
                // Публикуем только снимок, для которого не было новых событий во время чтения.
                collectionRootItems = items
                collectionRootItemsNeedsRefresh = false
            } else {
                // Текущий результат уже потенциально устарел, поэтому оставляем старые строки.
                collectionRootItemsNeedsRefresh = true
            }

            collectionRootRefreshRequestedWhileLoading = false
            collectionRootRefreshTask = nil

            if shouldRefreshAgain {
                refreshCollectionRootItems()
            }
        }
    }

    // MARK: - Private

    /// Строит шесть строк корня без ложных нулей до завершения первого чтения SQLite.
    private static let loadingCollectionRootItems = LibraryCollectionRootItem.rootItems.map {
        LibraryCollectionRootItemState(item: $0, count: nil)
    }

    /// Помечает корневые счётчики устаревшими после завершённого изменения данных.
    /// Пока выполняется чтение, несколько событий объединяются в один следующий снимок.
    private func invalidateCollectionRootItems() {
        collectionRootItemsNeedsRefresh = true

        guard collectionRootRefreshTask != nil else {
            refreshCollectionRootItems()
            return
        }

        collectionRootRefreshRequestedWhileLoading = true
    }

    /// Поля события трека, которые могут изменить строки или счётчики корня коллекции.
    private static let collectionRootChangedFields: Set<TrackChangedField> =
        LibraryCollectionCategory.allCases.reduce(into: Set<TrackChangedField>()) { fields, category in
            fields.formUnion(category.changedFields)
        }

    /// Проверяет событие, которое может изменить состав фонотеки или ключ участия трека.
    private static func affectsCollectionRoot(
        _ event: TrackUpdateEvent
    ) -> Bool {
        switch event.reason {
        case .fileMoved, .imported, .reloaded:
            // Перемещение может перевести imported-трек в фонотеку,
            // даже если payload содержит только изменение имени файла.
            return true
        case .metadataUpdated, .artworkUpdated, .fileRenamed, .availabilityUpdated:
            return event.changedFields.isDisjoint(with: collectionRootChangedFields) == false
        }
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
                }
            }
            .store(in: &cancellables)

        trackEventProvider.trackDidUpdate
            .sink { [weak self] event in
                Task { @MainActor in
                    guard Self.affectsCollectionRoot(event) else {
                        return
                    }

                    self?.invalidateCollectionRootItems()
                }
            }
            .store(in: &cancellables)

        trackEventProvider.trackBatchDidUpdate
            .sink { [weak self] events in
                Task { @MainActor in
                    guard events.contains(where: Self.affectsCollectionRoot) else {
                        return
                    }

                    self?.invalidateCollectionRootItems()
                }
            }
            .store(in: &cancellables)

        trackEventProvider.libraryDataDidChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.invalidateCollectionRootItems()
                }
            }
            .store(in: &cancellables)
    }
}

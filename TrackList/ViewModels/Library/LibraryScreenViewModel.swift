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

    // MARK: - Dependencies

    private let navigationCoordinator: NavigationCoordinator
    private let musicLibraryManager: MusicLibraryManager
    private let stateBuilder: LibraryScreenStateBuilder
    private let actionHandler: LibraryScreenActionHandler

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    init(
        navigationCoordinator: NavigationCoordinator,
        musicLibraryManager: MusicLibraryManager,
        stateBuilder: LibraryScreenStateBuilder,
        actionHandler: LibraryScreenActionHandler
    ) {
        self.navigationCoordinator = navigationCoordinator
        self.musicLibraryManager = musicLibraryManager
        self.stateBuilder = stateBuilder
        self.actionHandler = actionHandler
        self.screenState = stateBuilder.build(
            navigationCoordinator: navigationCoordinator,
            musicLibraryManager: musicLibraryManager
        )

        observeDependencies()
    }

    // MARK: - Actions

    func handle(_ action: LibraryScreenAction) {
        actionHandler.handle(action)
        refreshState()
    }

    // MARK: - Private

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
    }
}

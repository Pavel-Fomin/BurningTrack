//
//  NewTrackListSelectionFolderScreenStore.swift
//  TrackList
//
//  Удерживает screen-local graph папки выбора треков.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Combine

/// Собирает готовые selectable-строки из Library Tracks, Favorites и общего selection flow.
@MainActor
final class NewTrackListSelectionFolderScreenStore: ObservableObject {
    /// Готовое presentation-состояние, которое читает folder View.
    @Published private(set) var state: NewTrackListSelectionFolderScreenState

    /// ViewModel Library Tracks владеет загрузкой и runtime snapshot-ами папки.
    private let tracksViewModel: LibraryTracksViewModel
    /// Общая ViewModel selection сохраняет выбор между folder destination.
    private let selectionViewModel: NewTrackListSelectionViewModel
    /// Provider избранного обновляет подготовленные строки реактивно.
    private let favoriteTrackIDsProvider: any FavoriteTrackIdsProviding
    /// Обрабатывает lifecycle и snapshot intent без raw-вызовов из View.
    private let actionHandler: NewTrackListSelectionFolderActionHandler
    /// Собирает folder presentation-state до SwiftUI-слоя.
    private let presenter: NewTrackListSelectionFolderPresenter
    /// Последний опубликованный снимок избранного для построения строк.
    private var favoriteTrackIDs: Set<UUID>
    /// Подписки живут столько же, сколько и destination graph.
    private var cancellables = Set<AnyCancellable>()

    init(
        tracksViewModel: LibraryTracksViewModel,
        selectionViewModel: NewTrackListSelectionViewModel,
        favoriteTrackIDsProvider: any FavoriteTrackIdsProviding,
        actionHandler: NewTrackListSelectionFolderActionHandler,
        presenter: NewTrackListSelectionFolderPresenter
    ) {
        self.tracksViewModel = tracksViewModel
        self.selectionViewModel = selectionViewModel
        self.favoriteTrackIDsProvider = favoriteTrackIDsProvider
        self.actionHandler = actionHandler
        self.presenter = presenter
        self.favoriteTrackIDs = favoriteTrackIDsProvider.favoriteTrackIds
        self.state = Self.makeState(
            tracksViewModel: tracksViewModel,
            selectionState: selectionViewModel.state,
            favoriteTrackIDs: favoriteTrackIDsProvider.favoriteTrackIds,
            presenter: presenter
        )
        bindPresentationInputs()
    }

    /// Принимает только typed lifecycle и runtime-намерения folder View.
    func send(_ action: NewTrackListSelectionFolderAction) {
        actionHandler.handle(action)
    }

    /// Подписывается на все входы presentation-state, не раскрывая их SwiftUI View.
    private func bindPresentationInputs() {
        selectionViewModel.$state
            .sink { [weak self] _ in
                self?.updateState()
            }
            .store(in: &cancellables)

        tracksViewModel.$state
            .sink { [weak self] _ in
                self?.updateState()
            }
            .store(in: &cancellables)

        favoriteTrackIDsProvider.favoriteTrackIdsPublisher
            .sink { [weak self] favoriteTrackIDs in
                self?.favoriteTrackIDs = favoriteTrackIDs
                self?.updateState()
            }
            .store(in: &cancellables)

        tracksViewModel.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    await Task.yield()
                    self?.updateState()
                }
            }
            .store(in: &cancellables)
    }

    /// Пересобирает строки после изменения списка, runtime snapshot-а, избранного или selection.
    private func updateState() {
        state = Self.makeState(
            tracksViewModel: tracksViewModel,
            selectionState: selectionViewModel.state,
            favoriteTrackIDs: favoriteTrackIDs,
            presenter: presenter
        )
    }

    /// Выносит построение initial и последующего состояния в один presentation-путь.
    private static func makeState(
        tracksViewModel: LibraryTracksViewModel,
        selectionState: NewTrackListSelectionState,
        favoriteTrackIDs: Set<UUID>,
        presenter: NewTrackListSelectionFolderPresenter
    ) -> NewTrackListSelectionFolderScreenState {
        let tracksState = tracksViewModel.state
        let selectableSections = tracksViewModel.makeSelectableTrackSections(
            favoriteTrackIds: favoriteTrackIDs,
            selectedTrackIds: selectionState.selectedTrackIDs
        )

        return presenter.makeState(
            tracksState: tracksState,
            selectableSections: selectableSections,
            selectedTrackIDs: selectionState.selectedTrackIDs
        )
    }
}

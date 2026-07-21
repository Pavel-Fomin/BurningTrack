//
//  SearchScreen.swift
//  TrackList
//
//  Экран раздела поиска.
//  Created by Pavel Fomin on 08.07.2026.
//

import SwiftUI

struct SearchScreen: View {

    // MARK: - Dependencies

    @ObservedObject var playerViewModel: PlayerViewModel

    // MARK: - ViewModel

    @StateObject private var viewModel: SearchViewModel
    /// Системная активность нативного поиска нужна, чтобы не перекрывать search UI мини-плеером.
    @State private var isSearchActive = false

    // MARK: - Init

    init(playerViewModel: PlayerViewModel) {
        self.playerViewModel = playerViewModel
        self._viewModel = StateObject(
            wrappedValue: SearchViewModelFactory.make()
        )
    }

    /// Обработчик действий экрана поиска.
    private var actionHandler: SearchActionHandler {
        SearchActionHandler(
            viewModel: viewModel,
            playerViewModel: playerViewModel,
            navigationCoordinator: NavigationCoordinator.shared,
            sheetManager: SheetManager.shared,
            sheetActionCoordinator: SheetActionCoordinator.shared,
            fileRenamer: TrackFileRenameActionHandler(
                playerManager: playerViewModel.fileOperationPlayerManager,
                sheetManager: SheetManager.shared,
                commandExecutor: AppCommandExecutor.shared,
                toastManager: ToastManager.shared,
                proposalBuilder: FileRenameProposalBuilder()
            )
        )
    }

    /// Системный поиск пишет изменения в ViewModel через action layer.
    private var searchTextBinding: Binding<String> {
        Binding(
            get: {
                viewModel.state.query
            },
            set: { query in
                actionHandler.handle(.queryChanged(query))
            }
        )
    }

    // MARK: - UI

    var body: some View {
        NavigationStack {
            SearchView(
                state: viewModel.state,
                playerViewModel: playerViewModel,
                onSearchActivityChanged: { isActive in
                    isSearchActive = isActive
                },
                onAction: { action in
                    actionHandler.handle(action)
                }
            )
            .navigationTitle("Search")
            .toolbar {
                searchToolbarContent
            }
            .searchable(
                text: searchTextBinding,
                prompt: "Search"
            )
            .background(Color(.systemGroupedBackground))
            .onAppear {
                actionHandler.handle(.appeared)
            }
        }
        // Search toolbar должен сворачиваться при скролле так же, как навигационный заголовок.
        .searchToolbarBehavior(.minimize)
        // Search-tab presentation не должен забирать верхний navigation bar у экрана поиска.
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .miniPlayerHost(
            playerViewModel: playerViewModel,
            isVisible: isSearchActive == false
        )
    }

    // MARK: - Toolbar

    /// Верхняя кнопка сортировки появляется только после ввода запроса или при видимой выдаче.
    @ToolbarContentBuilder
    private var searchToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if shouldShowSortMenu {
                searchSortMenu
            }
        }
    }

    /// Показывает сортировку только когда у пользователя уже есть поисковый контекст.
    private var shouldShowSortMenu: Bool {
        viewModel.state.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            || viewModel.state.contentState == .results
    }

    /// Меню передаёт выбранный режим сортировки через action layer.
    private var searchSortMenu: some View {
        Menu {
            if usesGroupedSortMenu {
                ForEach(viewModel.state.availableSortModeGroups) { group in
                    if group.modes.count == 1,
                       let mode = group.modes.first {
                        searchSortButton(
                            mode: mode,
                            title: SearchPresentationText.sortGroupTitle(for: group)
                        )
                    } else {
                        Menu {
                            ForEach(group.modes) { mode in
                                searchSortButton(
                                    mode: mode,
                                    title: SearchPresentationText.groupedSortTitle(for: mode)
                                )
                            }
                        } label: {
                            Text(SearchPresentationText.sortGroupTitle(for: group))
                        }
                    }
                }
            } else {
                ForEach(viewModel.state.availableSortModes) { mode in
                    searchSortButton(
                        mode: mode,
                        title: SearchPresentationText.sortTitle(for: mode)
                    )
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
        .accessibilityLabel(String(localized: "Search Sorting"))
    }

    /// Для чипа "Все" показываем вложенные категории, для конкретного чипа — простой список.
    private var usesGroupedSortMenu: Bool {
        viewModel.state.availableSortModeGroups.count > 1
    }

    /// Пункт меню только меняет выбранный UI-режим сортировки.
    private func searchSortButton(
        mode: SearchSortMode,
        title: String
    ) -> some View {
        Button {
            actionHandler.handle(.selectSortMode(mode))
        } label: {
            Label {
                Text(title)
            } icon: {
                if viewModel.state.selectedSortMode == mode {
                    Image(systemName: "checkmark")
                }
            }
        }
    }
}

//
//  SearchScreen.swift
//  TrackList
//
//  Экран раздела поиска.
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI

struct SearchScreen: View {

    // MARK: - Dependencies

    @ObservedObject var playerViewModel: PlayerViewModel

    // MARK: - ViewModel

    @StateObject private var viewModel: SearchViewModel
    /// Системное состояние нативного поиска нужно, чтобы не перекрывать search UI мини-плеером.
    @State private var isSearchPresented = false

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
                onAction: { action in
                    actionHandler.handle(action)
                }
            )
            .navigationTitle("Поиск")
            .searchable(
                text: searchTextBinding,
                isPresented: $isSearchPresented,
                prompt: "Поиск"
            )
            .background(Color(.systemGroupedBackground))
            .onAppear {
                actionHandler.handle(.appeared)
            }
        }
        .miniPlayerHost(
            playerViewModel: playerViewModel,
            isVisible: isSearchPresented == false
        )
    }
}

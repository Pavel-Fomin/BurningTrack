//
//  TrackListsScreen.swift
//  TrackList
//
//  Раздел "Треклисты".
//  Навигация внутри этого раздела НЕ используется,
//  но NavigationStack обязателен для корректного тулбара и поведения вкладок.
//
//  Created by Pavel Fomin on 17.07.2025.
//

import SwiftUI

struct TrackListsScreen: View {

    @ObservedObject var trackListsViewModel: TrackListsViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    let trackListViewModel: TrackListViewModel

    /// Обрабатывает действия экрана списка треклистов.
    private var actionHandler: TrackListsActionHandler {
        TrackListsActionHandler(
            viewModel: trackListsViewModel,
            presenter: SheetManager.shared
        )
    }

    var body: some View {
        NavigationStack {
            TrackListsListView(
                state: trackListsViewModel.screenState,
                onAction: { action in
                    actionHandler.handle(action)
                },
                destination: { id in
                    guard let trackList = trackListsViewModel.trackLists.first(where: { $0.id == id }) else {
                        return AnyView(EmptyView())
                    }

                    return AnyView(
                        TrackListScreen(
                            trackList: trackList,
                            playerViewModel: playerViewModel
                        )
                    )
                }
            )
            .background(Color(.systemGroupedBackground))
            .trackListsToolbar(
                onCreateTrackList: {
                    actionHandler.handle(.createTrackList)
                }
            )
        }
        .miniPlayerHost(
            trackListViewModel: trackListViewModel,
            playerViewModel: playerViewModel
        )
    }
}

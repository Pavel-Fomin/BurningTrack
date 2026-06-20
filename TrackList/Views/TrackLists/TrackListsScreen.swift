//
//  TrackListsScreen.swift
//  TrackList
//
//  Раздел "Треклисты".
//  NavigationStack держит переход от списка треклистов к detail-экрану
//  и обеспечивает корректную работу тулбара внутри вкладки.
//
//  Created by Pavel Fomin on 17.07.2025.
//

import SwiftUI

struct TrackListsScreen: View {

    @ObservedObject var trackListsViewModel: TrackListsViewModel
    @ObservedObject var playerViewModel: PlayerViewModel

    /// Фабрика production action handler для master-flow списка треклистов.
    private let actionHandlerFactory = TrackListsActionHandlerFactory()

    /// Обрабатывает действия экрана списка треклистов.
    private var actionHandler: TrackListsActionHandler {
        actionHandlerFactory.make(
            viewModel: trackListsViewModel
        )
    }

    var body: some View {
        NavigationStack {
            TrackListsListView(
                state: trackListsViewModel.screenState,
                onAction: { action in
                    actionHandler.handle(action)
                },
                destination: { row in
                    TrackListScreen(
                        trackList: row.trackList,
                        playerViewModel: playerViewModel
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
            playerViewModel: playerViewModel
        )
    }
}

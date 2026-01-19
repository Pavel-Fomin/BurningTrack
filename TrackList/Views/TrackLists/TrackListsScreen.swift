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

    var body: some View {
        NavigationStack {
            TrackListsListView(
                viewModel: trackListsViewModel,
                playerViewModel: playerViewModel
            )
            .background(Color(.systemGroupedBackground))
            .trackListsToolbar()
        }
    }
}

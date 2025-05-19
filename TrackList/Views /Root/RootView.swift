//
//  RootView.swift
//  TrackList
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @StateObject var trackListViewModel: TrackListViewModel
    @StateObject var playerViewModel: PlayerViewModel

    init() {
        let trackListVM = TrackListViewModel()
        _trackListViewModel = StateObject(wrappedValue: trackListVM)
        _playerViewModel = StateObject(wrappedValue: PlayerViewModel(trackListViewModel: trackListVM))
    }

    var body: some View {
        NavigationStack {
            TrackListView(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel
            )
        }
    }
}

//
//  RootView.swift
//  TrackList
//
//  Created by Pavel Fomin on 28.04.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @StateObject var trackListViewModel = TrackListViewModel()
    @StateObject var playerViewModel = PlayerViewModel()

    var body: some View {
        NavigationStack {
            TrackListView(
                trackListViewModel: trackListViewModel,
                playerViewModel: playerViewModel
            )
        }
    }
}

struct RootView_Previews: PreviewProvider {
    static var previews: some View {
        RootView()
            .previewDevice("iPhone 15 Pro")
    }
}

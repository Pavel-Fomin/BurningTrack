//
//  TrackListsScreen.swift
//  TrackList
//
//  Раздел "Треклисты"
//
//  Created by Pavel Fomin on 17.07.2025.
//

import Foundation
import SwiftUI

struct TrackListsScreen: View {
    @ObservedObject var trackListsViewModel: TrackListsViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrackListsHeaderView()
                
                TrackListsListView(
                    viewModel: trackListsViewModel,
                    playerViewModel: playerViewModel
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

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
    @ObservedObject private var coordinator = NavigationCoordinator.shared
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
            NavigationStack(path: $navigationPath) {
                VStack(spacing: 0) {
                    TrackListsListView(
                        viewModel: trackListsViewModel,
                        playerViewModel: playerViewModel
                    )
                }
                .background(Color(.systemGroupedBackground))

                // Тулбар
                .trackListsToolbar()
            }
            .id(coordinator.resetTrackListsView)
        }
    }

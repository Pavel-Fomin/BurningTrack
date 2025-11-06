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
    @ObservedObject var trackListViewModel: TrackListViewModel
    @ObservedObject var playerViewModel: PlayerViewModel
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TrackListsHeaderView(
                    isEditing: trackListViewModel.isEditing,
                    onAdd: {
                        trackListViewModel.startImport()
                    },
                    onEditToggle: {
                        trackListViewModel.toggleEditMode()
                    }
                )
                
                TrackListsListView(
                    viewModel: trackListViewModel,
                    playerViewModel: playerViewModel
                )
            }
            .background(Color(.systemGroupedBackground))
        }
    }
}

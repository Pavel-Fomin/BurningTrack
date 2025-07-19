//
//  TrackListScreen.swift
//  TrackList
//
//  Список треков(Отображает треклист по ID)
//
//  Created by Pavel Fomin on 19.07.2025.
//

import Foundation
import SwiftUI

struct TrackListScreen: View {
    let trackList: TrackList
    @ObservedObject var playerViewModel: PlayerViewModel
    
    @StateObject private var viewModel = TrackListViewModel()
    
    var body: some View {
        TrackListView(
            trackListViewModel: viewModel,
            playerViewModel: playerViewModel
        )
        .padding(.horizontal, 16)
        .navigationTitle(trackList.name)
        .navigationBarTitleDisplayMode(.inline)
        
        }
    }


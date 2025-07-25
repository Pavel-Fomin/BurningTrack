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
    
    @StateObject private var viewModel: TrackListViewModel
    
    init(trackList: TrackList, playerViewModel: PlayerViewModel) {
        self.trackList = trackList
        self.playerViewModel = playerViewModel
        _viewModel = StateObject(wrappedValue: TrackListViewModel(trackList: trackList))
    }
    
    var body: some View {
        TrackListView(
            trackListViewModel: viewModel,
            playerViewModel: playerViewModel
        )
        .navigationTitle(trackList.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button("Экспортировать треки", action: handleExport)
                    
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }
    
    private func handleExport() {
        let importedTracks = viewModel.tracks.map { $0.asImportedTrack() }
        
        guard !importedTracks.isEmpty else {
            print("❌ Нет треков для экспорта")
            return
        }
        
        if let topVC = UIApplication.topViewController() {
            ExportManager.shared.exportViaTempAndPicker(importedTracks, presenter: topVC)
        } else {
            print("❌ Не удалось получить topViewController")
        }
    }
}

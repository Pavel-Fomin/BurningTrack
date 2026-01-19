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
    @EnvironmentObject var sheetManager: SheetManager
    
    init(trackList: TrackList, playerViewModel: PlayerViewModel) {
        self.trackList = trackList
        self.playerViewModel = playerViewModel
        _viewModel = StateObject(wrappedValue: TrackListViewModel(trackList: trackList))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                
                TrackListView(
                    trackListViewModel: viewModel,
                    playerViewModel: playerViewModel
                )
            }
            .trackListToolbar(
                viewModel: viewModel,
                onExport: handleExport,
                onRename: {
                    SheetManager.shared.presentRenameTrackList(
                        trackListId: viewModel.currentListId!,
                        currentName: viewModel.name
                    )
                }
            )
        }
        .onChange(of: sheetManager.dismissCounter) { _, _ in
            viewModel.refreshMeta()
        }
    }
    
    private func handleExport() {
        let tracks = viewModel.tracks
        
        guard !tracks.isEmpty else {
            print("❌ Нет треков для экспорта")
            return
        }
        
        if let topVC = UIApplication.topViewController() {
            ExportManager.shared.exportViaTempAndPicker(tracks, presenter: topVC)
        } else {
            print("❌ Не удалось получить topViewController")
        }
    }
}

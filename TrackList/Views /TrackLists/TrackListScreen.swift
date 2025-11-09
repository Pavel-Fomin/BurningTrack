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
        NavigationStack {
            VStack(spacing: 0) {
                
                // Контент
                TrackListView(
                    trackListViewModel: viewModel,
                    playerViewModel: playerViewModel
                )
            }
            // Тулбар
            .trackListToolbar(
                viewModel: viewModel,
                onExport: handleExport,
                onRename: {
                    viewModel.isShowingRenameSheet = true
                }
            )
            .sheet(isPresented: $viewModel.isShowingRenameSheet) {
                RenameTrackListSheet(
                    isPresented: $viewModel.isShowingRenameSheet,
                    currentName: viewModel.name
                ) { newName in
                    viewModel.renameCurrentTrackList(to: newName)
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

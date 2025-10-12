//
//  PlayerScreen.swift
//  TrackList
//
//  Вкладка “Плеер”
//
//  Created by Pavel Fomin on 22.06.2025.
//

import SwiftUI

struct PlayerScreen: View {
    @ObservedObject var playerViewModel: PlayerViewModel
    @State private var showImporter = false
    @State private var isShowingExportPicker = false
    @State private var isShowingSaveSheet = false
    @State private var trackListName: String = defaultTrackListName()
    
    @EnvironmentObject var toast: ToastManager
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Color(.systemBackground)
                    .ignoresSafeArea()
                VStack(spacing: 0) {
                    
        
// MARK: - Хедер
                    
                    PlayerHeaderView(
                        trackCount: PlaylistManager.shared.tracks.count,
                        onSave: {
                            PlaylistManager.shared.saveToDisk()
                        },
                        onExport: {
                            PlaylistManager.shared.exportCurrentTracks(to: URL(fileURLWithPath: "/"))
                            
                        },
                        onClear: {
                            PlaylistManager.shared.clear()
                        },
                        onSaveTrackList: {
                            isShowingSaveSheet = true
                        }
                    )
                    
                    
// MARK: - Список треков
                    
                    PlayerPlaylistView(playerViewModel: playerViewModel)
                }
            }
        }
        
// MARK: - Окно сохранения треклиста
        
        .sheet(isPresented: $isShowingSaveSheet) {
            SaveTrackListSheet(
                isPresented: $isShowingSaveSheet,
                name: $trackListName,
                onSave: {
                    let importedTracks = PlaylistManager.shared.tracks.map { $0.asImportedTrack() }
                    let newList = TrackListManager.shared.createTrackList(from: importedTracks, withName: trackListName)
                    toast.show(
                        ToastData(style: .trackList(name: newList.name), artwork: nil)
                    )
                }
            )
        }
    }
}


// MARK: - Вспомогательная функция (вне body)

        func defaultTrackListName() -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "dd.MM.yy, HH:mm"
            return formatter.string(from: Date())
        }


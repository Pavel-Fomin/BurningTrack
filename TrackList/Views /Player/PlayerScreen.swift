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
               VStack(spacing: 0) {

// MARK: - Список треков
                    
                    PlayerPlaylistView(playerViewModel: playerViewModel)
                }
            }
// MARK: - Тулбар (вместо PlayerHeaderView)
            
            .playerToolbar(
                trackCount: PlaylistManager.shared.tracks.count,
                onSave: {
                    PlaylistManager.shared.saveToDisk()
                },
                onExport: {
                    print("⚠️ Экспорт из плеера временно отключён")
                },
                onClear: {
                    PlaylistManager.shared.clear()
                },
                onSaveTrackList: {
                    isShowingSaveSheet = true
                }
            )
        }

// MARK: - Окно сохранения треклиста
        
        .sheet(isPresented: $isShowingSaveSheet) {
            SaveTrackListSheet(
                isPresented: $isShowingSaveSheet
            ) { name in
                let tracks = PlaylistManager.shared.tracks.map { $0.asTrack() }
                let newList = TrackListsManager.shared.createTrackList(from: tracks, withName: name)
                toast.show(
                    ToastData(style: .trackList(name: newList.name), artwork: nil)
                )
            }
        }
    }
}

// MARK: - Вспомогательная функция

private func defaultTrackListName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yy, HH:mm"
    return formatter.string(from: Date())
}

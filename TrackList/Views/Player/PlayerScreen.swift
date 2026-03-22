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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    PlayerPlaylistView(playerViewModel: playerViewModel)
                }
            }
            .playerToolbar(
                trackCount: PlaylistManager.shared.tracks.count,
                onSave: {PlaylistManager.shared.saveToDisk()},
                onExport: {handleExport()},
                onClear: {PlaylistManager.shared.clear()}
            )
        }
    }

    private func handleExport() {
        let tracks = PlaylistManager.shared.tracks.map {$0.asTrack()}

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

// MARK: - Вспомогательная функция

private func defaultTrackListName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yy, HH:mm"
    return formatter.string(from: Date())
}

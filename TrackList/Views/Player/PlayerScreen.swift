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
    let trackListViewModel: TrackListViewModel

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
                onSave: {
                    if PlaylistManager.shared.saveToDisk() {
                        ToastManager.shared.handle(.playlistSaved)
                    } else {
                        ToastManager.shared.handle(.playlistSaveFailed)
                    }
                },
                onExport: {handleExport()},
                onClear: {
                    Task {
                        await AppCommandExecutor.shared.clearPlayer()
                    }
                }
            )
        }
        .miniPlayerHost(
            trackListViewModel: trackListViewModel,
            playerViewModel: playerViewModel
        )
    }

    private func handleExport() {
        let tracks = PlaylistManager.shared.tracks.map {$0.asTrack()}

        guard !tracks.isEmpty else {
            ToastManager.shared.handle(.noTracksToExport)
            return
        }

        if let topVC = UIApplication.topViewController() {
            Task {
                do {
                    _ = try await ExportManager.shared.exportViaTempAndPicker(
                        tracks,
                        presenter: topVC
                    )
                } catch let appError as AppError {
                    ToastManager.shared.handle(appError)
                } catch {
                    ToastManager.shared.handle(.exportFailed)
                }
            }
        } else {
            ToastManager.shared.handle(.presenterUnavailable)
        }
    }
}

// MARK: - Вспомогательная функция

private func defaultTrackListName() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd.MM.yy, HH:mm"
    return formatter.string(from: Date())
}

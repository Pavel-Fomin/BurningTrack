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
        _viewModel = StateObject(
            wrappedValue: TrackListViewModel(
                trackList: trackList,
                renameActionHandler: TrackFileRenameActionHandler(
                    playerManager: playerViewModel.playerManager,
                    sheetManager: SheetManager.shared,
                    commandExecutor: AppCommandExecutor.shared,
                    toastManager: ToastManager.shared,
                    proposalBuilder: FileRenameProposalBuilder()
                )
            )
        )
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
                onAddTrack: {
                    guard let trackListId = viewModel.currentListId else { return }

                    SheetManager.shared.presentNewTrackListSelectionForAppend(
                        trackListId: trackListId
                    )
                },
                onExport: handleExport,
                onRename: {
                    SheetManager.shared.presentRenameTrackList(
                        trackListId: viewModel.currentListId!,
                        currentName: viewModel.name
                    )
                }
            )
        }
    }
    
    private func handleExport() {
        let tracks = viewModel.tracks
        
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

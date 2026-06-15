//
//  TrackListApp.swift
//  TrackList
//
//  файл запуска SwiftUI-приложения
//  TrackListViewModel() — управляет списком треков
//  PlayerViewModel() — управляет воспроизведением
//
//  Created by Pavel Fomin on 28.04.2025.
//


import SwiftUI

@main
struct TrackListApp: App {
    
    let trackListViewModel: TrackListViewModel
    let playerViewModel: PlayerViewModel
    
    init() {
        let playerVM = PlayerViewModel() // без аргументов
        let trackListVM = TrackListViewModel(
            renameActionHandler: TrackFileRenameActionHandler(
                playerManager: playerVM.playerManager,
                sheetManager: SheetManager.shared,
                commandExecutor: AppCommandExecutor.shared,
                toastManager: ToastManager.shared,
                proposalBuilder: FileRenameProposalBuilder()
            )
        )
        self.trackListViewModel = trackListVM
        self.playerViewModel = playerVM
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                playerViewModel: playerViewModel,
                trackListViewModel: trackListViewModel
            )
            .environmentObject(SheetManager.shared)
        }
    }
}

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
    
    @StateObject private var toast = ToastManager()


    init() {
        let trackListVM = TrackListViewModel()
        self.trackListViewModel = trackListVM
        self.playerViewModel = PlayerViewModel() // без аргументов
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                playerViewModel: playerViewModel,
                trackListViewModel: trackListViewModel
            )
            .environmentObject(toast)
            .environmentObject(SheetManager.shared)
        }
    }
}

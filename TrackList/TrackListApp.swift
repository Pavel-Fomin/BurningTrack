//
//  TrackListApp.swift
//  TrackList
//
//  файл запуска SwiftUI-приложения
//  PlayerViewModel() — управляет воспроизведением
//
//  Created by Pavel Fomin on 28.04.2025.
//


import SwiftUI

@main
struct TrackListApp: App {
    
    let playerViewModel: PlayerViewModel
    
    init() {
        let playerVM = PlayerViewModel() // без аргументов
        self.playerViewModel = playerVM
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                playerViewModel: playerViewModel
            )
            .environmentObject(SheetManager.shared)
        }
    }
}

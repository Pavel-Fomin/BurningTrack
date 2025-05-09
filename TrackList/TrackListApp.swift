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
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ContentView(
                    trackListViewModel: TrackListViewModel(),
                    playerViewModel: PlayerViewModel()
                )
            }
        }
    }
}

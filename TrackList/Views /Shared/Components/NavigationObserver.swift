//
//  NavigationObserver.swift
//  TrackList
//
//  Отслеживает команды навигации от NavigationCoordinator
//
//  Created by Pavel Fomin on 18.10.2025.
//


import Foundation
import SwiftUI
import Combine

final class NavigationObserver: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    @Published var requestedTrackURL: URL? = nil

    public init() { // ← добавили public
        NavigationCoordinator.shared.revealTrack
            .receive(on: RunLoop.main)
            .sink { [weak self] url in
                print("📨 NavigationObserver получил команду → \(url.lastPathComponent)")
                self?.requestedTrackURL = url
            }
            .store(in: &cancellables)
    }

    deinit {
        print("💀 NavigationObserver уничтожен")
    }
}

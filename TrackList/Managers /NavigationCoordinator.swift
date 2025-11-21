//
//  NavigationCoordinator.swift
//  TrackList
//
//  Центральный координатор для межвкладочной навигации
//
//  Created by Pavel Fomin on 16.10.2025.
//

import Foundation
import Combine

final class NavigationCoordinator: ObservableObject {
    static let shared = NavigationCoordinator()

    @Published var currentTab: Int = 0
    @Published var isLibraryReady: Bool = false
    @Published var pendingRevealTrackID: UUID? = nil
    @Published var resetTrackListsView = UUID()

    // Последний трек, который нужно “доставить” во фонотеку
    @Published private(set) var lastRevealedTrackID: UUID? = nil
    
    private init() {}
    

    // MARK: - Запрос показа трека во фонотеке
    func showInLibrary(trackId: UUID) {
        print("🧭 Запрос показать трек по id:", trackId)
        pendingRevealTrackID = trackId
        lastRevealedTrackID = trackId

        Task { @MainActor in
            ScenePhaseHandler.shared.activeTab = .library
        }
    }

    // MARK: - Уведомление о готовности LibraryScreen
    @MainActor
    func notifyLibraryReady() {
        print("📡 LibraryScreen готова принимать переходы")
        isLibraryReady = true
    }

    @MainActor
    func clearLastRevealedTrackID() {
        lastRevealedTrackID = nil
        print("🧹 NavigationCoordinator: очищен lastRevealedTrackID")
    }

    @MainActor
    func takeLastRevealedTrackID() -> UUID? {
        defer { lastRevealedTrackID = nil }
        return lastRevealedTrackID
    }

    func triggerTrackListsReset() {
        resetTrackListsView = UUID()
        print("↩️ Сброс экрана треклистов")
    }
}

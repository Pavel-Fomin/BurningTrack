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
    private(set) var lastRevealedTrack: URL? = nil     /// Последний трек, переданный во фонотеку (для новых подписчиков)
    var lastReadyLibraryURL: URL? = nil
    
    @Published var currentTab: Int = 0                 /// Текущая вкладка (0 – Плеер, 1 – Фонотека, 2 – Треклисты, 3 – Настройки)
    @Published var isLibraryReady: Bool = false
    @Published var pendingReveal: URL? = nil
    @Published var resetTrackListsView = UUID()        /// Cброса экрана треклистов
    
    private init() {}
    
    // MARK: - Запрос показа трека во фонотеке
    func showInLibrary(for url: URL) {
        print("🧭 Переключаемся во фонотеку для трека:", url.lastPathComponent)
        pendingReveal = url
        
        // Переключаем активную вкладку на фонотеку
        Task { @MainActor in
            ScenePhaseHandler.shared.activeTab = .library
        }
    }
    
    // MARK: - Уведомление о готовности LibraryScreen
    
    func notifyLibraryReady(for url: URL) {
        print("📡 LibraryScreen готова принимать переходы")
        lastReadyLibraryURL = url
        isLibraryReady = true
    }
    
    @MainActor
    func clearLastRevealedTrack() {
        lastRevealedTrack = nil
        print("🧹 NavigationCoordinator: очищен lastRevealedTrack")
    }
    
    @MainActor
    func takeLastRevealedTrack() -> URL? {
        defer { lastRevealedTrack = nil }
        return lastRevealedTrack
    }
    
    func triggerTrackListsReset() {
        resetTrackListsView = UUID()
        print("↩️ Сброс экрана треклистов")
    }
}

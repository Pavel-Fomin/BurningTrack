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
    let revealTrack = PassthroughSubject<URL, Never>() /// Паблишер для передачи URL трека во фонотеку
    private(set) var lastRevealedTrack: URL? = nil     /// Последний трек, переданный во фонотеку (для новых подписчиков)
    
    @Published var currentTab: Int = 0                 /// Текущая вкладка (0 – Плеер, 1 – Фонотека, 2 – Треклисты, 3 – Настройки)
    @Published var isLibraryReady: Bool = false
    var lastReadyLibraryURL: URL? = nil
    
    private init() {}
    
    
// MARK: - Запрос показа трека во фонотеке
    
    func showInLibrary(for trackURL: URL) {
        print("🧭 Переключаемся во фонотеку для трека: \(trackURL.lastPathComponent)")
        lastRevealedTrack = trackURL
        revealTrack.send(trackURL)
    }
    
// MARK: - Уведомление о готовности LibraryScreen
    
    func notifyLibraryReady(for url: URL) {
        print("📡 LibraryScreen готова принимать переходы")
        lastReadyLibraryURL = url
        isLibraryReady = true
    }
}

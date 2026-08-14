//
//  SheetActionCoordinator.swift
//  TrackList
//
//  Координатор межэкранной навигации из действий над треком.
//
//  Отвечает за:
//  - переход к треку в фонотеке
//
//  НЕ содержит бизнес-логики.
//  НЕ выполняет команды.
//  НЕ знает про AppCommandExecutor.
//
//  Command-based UI Architecture.
//
//  Created by Pavel Fomin on 20.12.2025.
//

import Foundation

@MainActor
final class SheetActionCoordinator {

    // MARK: - Единый экземпляр

    static let shared = SheetActionCoordinator()
    private init() {}

    // MARK: - Зависимости

    private let navigationCoordinator = NavigationCoordinator.shared

    // MARK: - Обработка действий над треком

    /// Переходит к треку в фонотеке, не меняя состояние активного sheet.
    func showInLibrary(_ track: any TrackDisplayable) {
        navigationCoordinator.showInLibrary(track)
    }
}

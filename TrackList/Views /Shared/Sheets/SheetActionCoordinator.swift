//
//  SheetActionCoordinator.swift
//  TrackList
//
//  Координатор UI-действий, инициируемых из sheet’ов.
//
//  Отвечает за:
//  - интерпретацию TrackAction
//  - открытие следующих sheet’ов
//  - навигацию между экранами
//  - закрытие текущего sheet
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

    // MARK: - Singleton

    static let shared = SheetActionCoordinator()
    private init() {}

    // MARK: - Зависимости

    private let sheetManager = SheetManager.shared
    private let navigationCoordinator = NavigationCoordinator.shared

    // MARK: - Обработка действий над треком

    /// Обрабатывает действие над треком, инициированное из sheet.
    ///
    /// - Parameters:
    ///   - action: Действие, выбранное пользователем.
    ///   - track: Трек, к которому применяется действие.
    ///   - context: Контекст, из которого вызвано действие.
    ///
    func handle(
        action: TrackAction,
        track: any TrackDisplayable,
        context: TrackContext
    ) {
        switch action {

        case .moveToFolder:
            // 1. Закрываем текущий sheet
            sheetManager.closeActive()

            // 2. Открываем sheet перемещения
            sheetManager.presentMoveToFolder(for: track)

        case .showInLibrary:
            // Переходим к треку в фонотеке
            navigationCoordinator.showTrackInLibrary(trackId: track.id)

            // Закрываем текущий sheet
            sheetManager.closeActive()

        case .showInfo:
            // Открываем sheet с информацией о треке
            sheetManager.presentTrackDetail(track)
        }
    }
}

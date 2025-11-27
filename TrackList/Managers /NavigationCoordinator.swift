//
//  NavigationCoordinator.swift
//  TrackList
//
//  Центральный координатор для межвкладочной навигации и фонотеки.
//
//  - Управляет только маршрутом фонотеки (libraryRoute)
//  - Умеет переключать вкладки через ScenePhaseHandler
//  - Принимает событие "показать трек во фонотеке" (showTrackInLibrary)
//    и отдаёт его на потребление через consumePendingShowTrackId()
//
//  Created by Pavel Fomin on 16.10.2025.
//

import SwiftUI
import Foundation

@MainActor
final class NavigationCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = NavigationCoordinator()

    // MARK: - Состояние навигации

    /// Маршрут внутри раздела “Фонотека”
    @Published var libraryRoute: LibraryRoute = .root

    /// Отложенное событие "показать трек во фонотеке".
    /// Используется, когда другая вкладка просит открыть трек в фонотеке.
    private var pendingShowTrackId: UUID? = nil

    private init() {}

    // MARK: - Работа с вкладками

    /// Переключает активную вкладку приложения.
    func setTab(_ tab: ScenePhaseHandler.Tab) {
        ScenePhaseHandler.shared.activeTab = tab
    }

    // MARK: - Маршруты фонотеки

    /// Открывает корень фонотеки (список прикреплённых папок).
    func openLibraryRoot() {
        libraryRoute = .root
    }

    /// Открывает конкретную папку во фонотеке по её ID.
    func openFolder(_ id: UUID) {
        libraryRoute = .folder(id: id)
    }

    // MARK: - Переадресация "показать трек во фонотеке"

    /// Вызывается из плеера / треклиста, чтобы показать трек во фонотеке.
    /// Здесь мы:
    /// 1) запоминаем ID трека
    /// 2) переключаемся на вкладку "Фонотека"
    func showTrackInLibrary(trackId: UUID) {
        pendingShowTrackId = trackId
        setTab(.library)
    }

    /// Вызывается из LibraryScreen (или другого корневого экрана фонотеки),
    /// чтобы забрать отложенный trackId и сразу очистить его.
    ///
    /// Пример использования:
    /// if let trackId = NavigationCoordinator.shared.consumePendingShowTrackId() {
    ///     viewModel.focusOnTrack(with: trackId)
    /// }
    func consumePendingShowTrackId() -> UUID? {
        guard let id = pendingShowTrackId else { return nil }
        pendingShowTrackId = nil
        return id
    }

    // MARK: - Вложенные типы

    /// Маршрут внутри раздела “Фонотека”.
    enum LibraryRoute: Equatable {
        case root
        case folder(id: UUID)
    }
}

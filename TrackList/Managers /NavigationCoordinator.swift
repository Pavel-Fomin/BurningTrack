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

    /// Стек маршрутов для NavigationStack.
    /// Пустой массив = корень фонотеки.
    @Published var libraryPath: [LibraryRoute] = []

    /// Отложенное событие "показать трек во фонотеке".
    private var pendingShowTrackId: UUID? = nil

    private init() {}

    // MARK: - API для UI (тулбара)

    /// Находимся ли мы в корне.
    var isAtRoot: Bool {
        libraryPath.isEmpty
    }

    /// Текущий маршрут (верхушка стека).
    var currentRoute: LibraryRoute {
        libraryPath.last ?? .root
    }

    // MARK: - Работа с вкладками

    func setTab(_ tab: ScenePhaseHandler.Tab) {
        ScenePhaseHandler.shared.activeTab = tab
    }

    // MARK: - Навигация внутри фонотеки

    /// Полный сброс в корень.
    func openLibraryRoot() {
        libraryPath = []        // корень = пустой стек
    }

    /// Открытие папки ИЗ КОРНЯ (заменяет весь стек).
    func openFolder(_ id: UUID) {
        libraryPath = [.folder(id)]
    }

    /// Переход внутрь папки (вложенный уровень).
    func pushFolder(_ id: UUID) {
        libraryPath.append(.folder(id))
    }

    /// Переход в список треков папки.
    func pushTracksInFolder(_ id: UUID) {
        libraryPath.append(.tracksInFolder(id))
    }

    /// Возврат на один уровень назад.
    func popLibrary() {
        guard !libraryPath.isEmpty else { return }
        libraryPath.removeLast()
    }

    // MARK: - Переадресация "показать трек во фонотеке"

    func showTrackInLibrary(trackId: UUID) {
        pendingShowTrackId = trackId
        setTab(.library)
    }

    func consumePendingShowTrackId() -> UUID? {
        defer { pendingShowTrackId = nil }
        return pendingShowTrackId
    }

    // MARK: - Маршруты

    enum LibraryRoute: Hashable {
        case root
        case folder(UUID)
        case tracksInFolder(UUID)
    }
}

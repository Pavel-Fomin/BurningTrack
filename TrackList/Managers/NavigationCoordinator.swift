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
//  - Хранит одноразовый reveal intent отдельно от маршрута папки
//
//  Created by Pavel Fomin on 16.10.2025.
//

import SwiftUI
import Foundation

struct LibraryRevealRequest: Equatable {
    let folderId: UUID
    let targetTrackId: UUID
    let requestId: UUID
}

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

    /// Одноразовый intent подсветки трека внутри открытой папки.
    @Published private(set) var pendingRevealRequest: LibraryRevealRequest?

    private init() {}

    // MARK: - API для UI

    /// Находимся ли мы в корне фонотеки.
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
        libraryPath = []
    }

    /// Открытие папки ИЗ КОРНЯ (заменяет весь стек).
    func openFolder(_ folderId: UUID) {
        libraryPath = [.folder(folderId)]
    }

    /// Переход внутрь папки (вложенный уровень).
    func pushFolder(_ id: UUID) {
        libraryPath.append(.folder(id))
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

    func setPendingRevealRequest(folderId: UUID, targetTrackId: UUID) {
        pendingRevealRequest = LibraryRevealRequest(
            folderId: folderId,
            targetTrackId: targetTrackId,
            requestId: UUID()
        )
    }

    func clearRevealRequest(requestId: UUID) {
        guard pendingRevealRequest?.requestId == requestId else { return }
        pendingRevealRequest = nil
    }

    // MARK: - Маршруты

    enum LibraryRoute: Hashable {
        case root
        case folder(UUID)
    }
}

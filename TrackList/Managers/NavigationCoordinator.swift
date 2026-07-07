//
//  NavigationCoordinator.swift
//  TrackList
//
//  Центральный координатор для межвкладочной навигации и фонотеки.
//
//  - Управляет только стеком маршрутов фонотеки (libraryPath)
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

struct TrackListOpenRequest: Equatable {
    let trackListId: UUID
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
    /// Одноразовый intent открытия треклиста из другого раздела приложения.
    @Published private(set) var pendingTrackListOpenRequest: TrackListOpenRequest?

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

    /// Открывает папку фонотеки из внешнего раздела и переключает вкладку.
    func openLibraryFolderFromApp(_ folderId: UUID) {
        openFolder(folderId)
        setTab(.library)
    }

    /// Запрашивает открытие треклиста во вкладке треклистов.
    func openTrackListFromApp(_ trackListId: UUID) {
        pendingTrackListOpenRequest = TrackListOpenRequest(
            trackListId: trackListId,
            requestId: UUID()
        )
        setTab(.tracklists)
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

    /// Открытие виртуального источника купленных треков iTunes из корня фонотеки.
    func openPurchasedITunes() {
        libraryPath = [.purchasedITunes]
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

    func clearTrackListOpenRequest(requestId: UUID) {
        guard pendingTrackListOpenRequest?.requestId == requestId else { return }
        pendingTrackListOpenRequest = nil
    }

    // MARK: - Маршруты

    enum LibraryRoute: Hashable {
        case root
        /// Виртуальный источник купленных треков iTunes, не связанный с LibraryFolder.
        case purchasedITunes
        case folder(UUID)
    }
}

//
//  NavigationCoordinator.swift
//  TrackList
//
//  Центральный координатор для межвкладочной навигации и фонотеки.
//
//  - Управляет только стеком маршрутов фонотеки (libraryPath)
//  - Умеет переключать вкладки через ScenePhaseHandler
//  - Принимает событие "показать трек во фонотеке" (showInLibrary)
//    и отдаёт его на потребление через consumePendingShowInLibraryRequest()
//  - Хранит одноразовый reveal intent отдельно от маршрута назначения
//
//  Created by Pavel Fomin on 16.10.2025.
//

import SwiftUI
import Foundation

/// Назначение внутри фонотеки, где должна быть найдена строка трека.
enum LibraryRevealDestination: Equatable {
    /// Обычная папка фонотеки приложения.
    case folder(UUID)
    /// Виртуальный раздел купленных треков iTunes.
    case purchasedITunes
}

/// Единый intent показа трека в фонотеке до определения конечного маршрута.
struct ShowInLibraryRequest: Equatable {
    enum Source: Equatable {
        /// Обычный трек, расположение которого определяется через TrackRegistry.
        case library
        /// Runtime-трек из системной медиатеки iTunes.
        case purchasedITunes
    }

    let trackId: UUID
    let source: Source
}

/// Одноразовый intent прокрутки к треку после открытия конечного раздела.
struct LibraryRevealRequest: Equatable {
    let destination: LibraryRevealDestination
    let targetTrackId: UUID
    let requestId: UUID
}

struct TrackListOpenRequest: Equatable {
    let trackListId: UUID
    let requestId: UUID
}

@MainActor
final class NavigationCoordinator: ObservableObject {

    // MARK: - Единый экземпляр

    static let shared = NavigationCoordinator()

    // MARK: - Состояние навигации

    /// Стек маршрутов для NavigationStack.
    /// Пустой массив = корень фонотеки.
    @Published var libraryPath: [LibraryRoute] = []

    /// Отложенное событие "показать трек во фонотеке" с типизированным источником.
    @Published private(set) var pendingShowInLibraryRequest: ShowInLibraryRequest?

    /// Одноразовый intent подсветки и прокрутки внутри открытого раздела фонотеки.
    @Published private(set) var pendingRevealRequest: LibraryRevealRequest?
    /// Одноразовый intent открытия треклиста из другого раздела приложения.
    @Published private(set) var pendingTrackListOpenRequest: TrackListOpenRequest?

    private init() {}

    // MARK: - API для интерфейса

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

    /// Открывает конкретное значение музыкальной коллекции и переключает приложение на вкладку фонотеки.
    func openCollectionValueFromApp(
        category: LibraryCollectionCategory,
        value: String,
        artistKey: String? = nil
    ) {
        libraryPath = [
            .collectionCategory(category),
            .collectionValue(
                category: category,
                value: value,
                artistKey: artistKey
            )
        ]
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

    /// Открывает полный список треков фонотеки.
    func openAllLibraryTracks() {
        libraryPath = [.allLibraryTracks]
    }

    /// Открытие раздела музыкальной коллекции из корня фонотеки.
    func openCollectionCategory(_ category: LibraryCollectionCategory) {
        libraryPath = [.collectionCategory(category)]
    }

    /// Переход к выбранному значению раздела коллекции.
    func pushCollectionValue(
        category: LibraryCollectionCategory,
        value: String,
        artistKey: String? = nil
    ) {
        libraryPath.append(
            .collectionValue(
                category: category,
                value: value,
                artistKey: artistKey
            )
        )
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

    /// Запускает общий сценарий показа трека в фонотеке с учётом его источника.
    func showInLibrary(_ track: any TrackDisplayable) {
        pendingShowInLibraryRequest = ShowInLibraryRequest(
            trackId: track.trackId,
            source: showInLibrarySource(for: track)
        )
        setTab(.library)
    }

    /// Возвращает и очищает ожидающий сценарий показа трека в фонотеке.
    func consumePendingShowInLibraryRequest() -> ShowInLibraryRequest? {
        defer { pendingShowInLibraryRequest = nil }
        return pendingShowInLibraryRequest
    }

    /// Создаёт одноразовый запрос прокрутки для уже выбранного назначения фонотеки.
    func setPendingRevealRequest(
        destination: LibraryRevealDestination,
        targetTrackId: UUID
    ) {
        pendingRevealRequest = LibraryRevealRequest(
            destination: destination,
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

    /// Определяет источник по типизированной runtime-модели без эвристик по названию или идентификатору.
    private func showInLibrarySource(
        for track: any TrackDisplayable
    ) -> ShowInLibraryRequest.Source {
        guard let sourceTrack = track as? any PurchasedITunesTrackRepresentable,
              sourceTrack.source == .purchasedITunes else {
            return .library
        }

        return .purchasedITunes
    }

    // MARK: - Маршруты

    enum LibraryRoute: Hashable {
        case root
        /// Виртуальный источник купленных треков iTunes, не связанный с LibraryFolder.
        case purchasedITunes
        /// Полный список треков фонотеки из режима корня "Треки".
        case allLibraryTracks
        /// Раздел музыкальной коллекции из режима корня "Треки".
        case collectionCategory(LibraryCollectionCategory)
        /// Значение раздела коллекции, открывающее список связанных треков.
        case collectionValue(category: LibraryCollectionCategory, value: String, artistKey: String?)
        case folder(UUID)
    }
}

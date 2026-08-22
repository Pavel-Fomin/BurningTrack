//
//  SQLiteTrackListsTestSupport.swift
//  TrackList
//
//  Изолированные test doubles для SQLite-проверок master-состояния треклистов.
//
//  Created by Pavel Fomin on 22.08.2026.
//

import Combine
import XCTest
@testable import TrackList

// Проверяет порядок вызовов ViewModel без обращения к SQLite.
@MainActor
final class TrackListsLoadingOrderSpy: TrackListsManaging {
    enum Call: Equatable {
        case ensureFavorites
        case loadMetas
        case delete(UUID)
        case updateOrder([UUID])
    }

    private(set) var calls: [Call] = []
    private var metas: [TrackListMeta]

    init(metas: [TrackListMeta]) {
        self.metas = metas
    }

    func ensureFavoritesTrackList() throws -> TrackListMeta {
        calls.append(.ensureFavorites)

        guard let favorites = metas.first(where: { $0.kind == .favorites }) else {
            throw AppError.trackListNotFound
        }

        return favorites
    }

    func favoritesTrackList() throws -> TrackListMeta? {
        metas.first { $0.kind == .favorites }
    }

    func loadTrackListMetas() throws -> [TrackListMeta] {
        calls.append(.loadMetas)
        return metas
    }

    func deleteTrackList(id: UUID) throws {
        guard let index = metas.firstIndex(where: { $0.id == id }) else {
            throw AppError.trackListNotFound
        }

        calls.append(.delete(id))
        metas.remove(at: index)
    }

    func renameTrackList(id: UUID, to newName: String) throws {
        throw AppError.trackListNotFound
    }

    func updateTrackListsOrder(_ orderedIds: [UUID]) throws {
        calls.append(.updateOrder(orderedIds))
    }
}

// Возвращает пустое содержимое треклиста, чтобы проверить только порядок загрузки метаданных.
@MainActor
final class TrackListLoadingOrderSpy: TrackListManaging {
    func loadTracks(for id: UUID) throws -> [Track] {
        []
    }

    func saveTracks(_ tracks: [Track], for id: UUID) throws -> TrackListTracksSaveReceipt {
        TrackListTracksSaveReceipt(trackListId: id, savedTracksCount: tracks.count)
    }
}

// Не показывает интерфейсные ошибки в модульном тесте порядка загрузки.
@MainActor
final class TrackListsToastPresenterSpy: ToastPresenting {
    func handle(_ event: ToastEvent, duration: TimeInterval) {}

    func handle(_ error: AppError) {}
}

extension TrackListsToastPresenterSpy: TrackListsLoadFailurePresenting {

    func presentTrackListsLoadFailure(_ error: AppError) {}
}

// Не меняет реальную sidebar-навигацию в изолированной проверке загрузки master-снимка.
@MainActor
final class TrackListsNavigationPruningSpy: TrackListsNavigationPruning {

    func pruneTrackListSelection(validTrackListIDs: Set<UUID>) {}
}

// Предоставляет ViewModel минимальные настройки без обращения к рабочему глобальному объекту.
@MainActor
final class TrackListsSettingsManagerSpy: SettingsManaging {
    @Published private var currentSettings = AppSettings.defaultValue

    var settings: AppSettings {
        currentSettings
    }

    var settingsPublisher: Published<AppSettings>.Publisher {
        $currentSettings
    }

    func setTagReadingEnabled(_ value: Bool) {
        currentSettings.visible.metadata.isTagReadingEnabled = value
    }

    func setTrackListMembershipVisible(_ value: Bool) {
        currentSettings.visible.library.isTrackListMembershipVisible = value
    }

    func setFileFormatVisible(_ value: Bool) {
        currentSettings.visible.library.isFileFormatVisible = value
    }

    func setPurchasedITunesSourceVisible(_ value: Bool) {
        currentSettings.visible.library.isPurchasedITunesSourceVisible = value
    }

    func setMiniPlayerExpanded(_ value: Bool) {
        currentSettings.internalSettings.isMiniPlayerExpanded = value
    }

    func setLibraryRootDisplayMode(_ mode: LibraryRootDisplayMode) throws {
        currentSettings.internalSettings.libraryRootDisplayMode = mode
    }

    func setLibraryTrackSortMode(_ mode: LibraryTrackSortMode) throws {
        currentSettings.internalSettings.libraryTrackSortMode = mode
    }

    func setTrackListsSortMode(_ mode: TrackListsSortMode?) throws {
        currentSettings.internalSettings.trackListsSortMode = mode
    }

    func applyPersistedTrackListsSortMode(_: TrackListsSortMode?) {
        // Этот test double не хранит состояние сортировки треклистов.
    }
}

// Не публикует внешние события, чтобы проверка была ограничена первой загрузкой ViewModel.
@MainActor
final class TrackListsEventProviderSpy: TrackListsEventProviding {
    private let subject = PassthroughSubject<Void, Never>()

    var trackListsDidChange: AnyPublisher<Void, Never> {
        subject.eraseToAnyPublisher()
    }
}

//
//  FavoriteTrackActionHandlerTests.swift
//  TrackList
//
//  Проверяет передачу переключения «Избранного» в общий доменный сервис.
//
//  Created by Pavel Fomin on 01.08.2026.
//

import XCTest
@testable import TrackList

/// Проверяет общий маршрут действия меню без SQLite и SwiftUI.
@MainActor
final class FavoriteTrackActionHandlerTests: XCTestCase {

    /// Toggle передаёт снимок трека ровно в один общий доменный сервис.
    func testTogglePassesTrackInputToFavoritesService() {
        let service = FavoriteTrackActionServiceSpy()
        let handler = FavoriteTrackActionHandler(favoritesService: service)
        let track = FavoriteTrackInput(
            trackId: UUID(),
            title: "Track",
            artist: "Artist",
            duration: 180,
            fileName: "track.mp3",
            isAvailable: true
        )

        handler.toggle(track)

        XCTAssertEqual(service.toggleInputs, [track])
    }

    func testTogglePersistenceFailureUsesExistingToastPresenter() {
        let toast = FavoriteTrackToastSpy()
        let handler = FavoriteTrackActionHandler(
            favoritesService: FavoriteTrackActionFailingServiceSpy(),
            toastPresenter: toast
        )

        let result = handler.toggle(
            FavoriteTrackInput(
                trackId: UUID(),
                title: "Track",
                artist: nil,
                duration: 180,
                fileName: "track.mp3",
                isAvailable: true
            )
        )

        guard case .failed = result else {
            return XCTFail("Ошибка persist не должна формировать подтверждённый результат")
        }
        XCTAssertEqual(toast.errors, [.trackListSaveFailed])
    }
}

/// Записывает обращение к доменному контракту без доступа к постоянному хранилищу.
@MainActor
private final class FavoriteTrackActionServiceSpy: FavoritesServicing {

    private(set) var toggleInputs: [FavoriteTrackInput] = []

    func loadFavoriteTrackIds() throws -> Set<UUID> {
        []
    }

    func isFavorite(trackId: UUID) throws -> Bool {
        false
    }

    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        .added
    }

    func remove(trackId: UUID) throws -> FavoritesMutationResult {
        .removed
    }

    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        toggleInputs.append(track)
        return .added
    }
}

/// Имитирует ошибку сохранения без изменения опубликованного состояния избранного.
@MainActor
private final class FavoriteTrackActionFailingServiceSpy: FavoritesServicing {
    func loadFavoriteTrackIds() throws -> Set<UUID> { [] }
    func isFavorite(trackId: UUID) throws -> Bool { false }
    func add(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult { .added }
    func remove(trackId: UUID) throws -> FavoritesMutationResult { .removed }

    func toggle(_ track: FavoriteTrackInput) throws -> FavoritesMutationResult {
        throw AppError.trackListSaveFailed
    }
}

/// Фиксирует presentation-ошибку без создания отдельного Toast-механизма.
@MainActor
private final class FavoriteTrackToastSpy: ToastPresenting {
    private(set) var errors: [AppError] = []

    func handle(_ event: ToastEvent, duration: TimeInterval) {}

    func handle(_ error: AppError) {
        errors.append(error)
    }
}

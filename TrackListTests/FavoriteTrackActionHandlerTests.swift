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

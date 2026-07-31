//
//  TrackMenuActionAvailabilityTests.swift
//  TrackList
//
//  Проверяет доступность общего действия «Поделиться» во всех меню одного трека.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import XCTest
@testable import TrackList

/// Проверяет, что системная отправка доступна для каждого поддерживаемого источника и экрана.
final class TrackMenuActionAvailabilityTests: XCTestCase {

    /// Локальный файл получает действие в фонотеке, плеере и треклисте.
    func testLocalTrackShareIsAvailableInAllStandardMenus() {
        assertShareAvailability(
            source: .library,
            contexts: [.library, .player, .trackList]
        )
    }

    /// Imported-файл получает действие в меню плеера и треклиста, где он уже поддержан проектом.
    func testImportedTrackShareIsAvailableInSupportedMenus() {
        assertShareAvailability(
            source: .imported,
            contexts: [.player, .trackList]
        )
    }

    /// Runtime iTunes-ассет получает действие в экране медиатеки, плеере и треклисте.
    func testPurchasedITunesTrackShareIsAvailableInAllStandardMenus() {
        assertShareAvailability(
            source: .purchasedITunes,
            contexts: [.purchasedITunes, .player, .trackList]
        )
    }

    /// iTunes-трек можно показать из плеера и треклиста, но не повторно из открытого раздела iTunes.
    func testPurchasedITunesTrackShowInLibraryIsAvailableOutsidePurchasedITunesSection() {
        XCTAssertTrue(
            TrackMenuActionAvailability.isAvailable(
                .showInLibrary,
                source: .purchasedITunes,
                context: .player
            )
        )
        XCTAssertTrue(
            TrackMenuActionAvailability.isAvailable(
                .showInLibrary,
                source: .purchasedITunes,
                context: .trackList
            )
        )
        XCTAssertFalse(
            TrackMenuActionAvailability.isAvailable(
                .showInLibrary,
                source: .purchasedITunes,
                context: .purchasedITunes
            )
        )
    }

    /// Все источники со стабильным trackId получают переключатель в поддерживаемых меню.
    func testFavoriteToggleIsAvailableInSupportedMenus() {
        assertFavoriteAvailability(
            source: .library,
            contexts: [.library, .player, .trackList]
        )
        assertFavoriteAvailability(
            source: .imported,
            contexts: [.player, .trackList]
        )
        assertFavoriteAvailability(
            source: .purchasedITunes,
            contexts: [.purchasedITunes, .player, .trackList]
        )
    }

    /// Не поддерживаемый контекст не получает визуально неработающий пункт меню.
    func testFavoriteToggleIsUnavailableOutsideSupportedMenus() {
        XCTAssertFalse(
            TrackMenuActionAvailability.isAvailable(
                .toggleFavorite,
                source: .imported,
                context: .library
            )
        )
        XCTAssertFalse(
            TrackMenuActionAvailability.isAvailable(
                .toggleFavorite,
                source: .purchasedITunes,
                context: .library
            )
        )
    }

    /// Неизбранный трек использует ту же пустую иконку сердца, что и мини-плеер.
    func testFavoriteMenuPresentationUsesEmptyHeartForNonFavoriteTrack() {
        XCTAssertEqual(
            TrackFavoriteMenuPresentation(isFavorite: false).systemImage,
            "heart"
        )
    }

    /// Избранный трек использует ту же заполненную иконку сердца, что и мини-плеер.
    func testFavoriteMenuPresentationUsesFilledHeartForFavoriteTrack() {
        XCTAssertEqual(
            TrackFavoriteMenuPresentation(isFavorite: true).systemImage,
            "heart.fill"
        )
    }

    /// Два доступных назначения объединяются во вложенный пункт «Добавить в».
    func testAddDestinationMenuGroupsBothAvailableActions() {
        XCTAssertEqual(
            TrackAddDestinationMenuPresentation(
                canAddToPlayer: true,
                canAddToTrackList: true
            ),
            .grouped
        )
    }

    /// Единственное доступное назначение плеера остаётся самостоятельным пунктом.
    func testAddDestinationMenuKeepsPlayerActionStandalone() {
        XCTAssertEqual(
            TrackAddDestinationMenuPresentation(
                canAddToPlayer: true,
                canAddToTrackList: false
            ),
            .addToPlayer
        )
    }

    /// Единственное доступное назначение треклиста остаётся самостоятельным пунктом.
    func testAddDestinationMenuKeepsTrackListActionStandalone() {
        XCTAssertEqual(
            TrackAddDestinationMenuPresentation(
                canAddToPlayer: false,
                canAddToTrackList: true
            ),
            .addToTrackList
        )
    }

    /// При отсутствии доступных назначений блок добавления не отображается.
    func testAddDestinationMenuHidesUnavailableActions() {
        XCTAssertEqual(
            TrackAddDestinationMenuPresentation(
                canAddToPlayer: false,
                canAddToTrackList: false
            ),
            .none
        )
    }

    /// Две доступные цели перехода объединяются во вложенный пункт «Перейти к».
    func testGoToDestinationMenuGroupsBothAvailableActions() {
        XCTAssertEqual(
            TrackGoToDestinationMenuPresentation(
                canGoToArtist: true,
                canGoToAlbum: true
            ),
            .grouped
        )
    }

    /// Единственная доступная цель артиста остаётся самостоятельным пунктом.
    func testGoToDestinationMenuKeepsArtistActionStandalone() {
        XCTAssertEqual(
            TrackGoToDestinationMenuPresentation(
                canGoToArtist: true,
                canGoToAlbum: false
            ),
            .goToArtist
        )
    }

    /// Единственная доступная цель альбома остаётся самостоятельным пунктом.
    func testGoToDestinationMenuKeepsAlbumActionStandalone() {
        XCTAssertEqual(
            TrackGoToDestinationMenuPresentation(
                canGoToArtist: false,
                canGoToAlbum: true
            ),
            .goToAlbum
        )
    }

    /// При отсутствии доступных целей блок перехода не отображается.
    func testGoToDestinationMenuHidesUnavailableActions() {
        XCTAssertEqual(
            TrackGoToDestinationMenuPresentation(
                canGoToArtist: false,
                canGoToAlbum: false
            ),
            .none
        )
    }

    /// Сверяет наличие общего действия без привязки к конкретной SwiftUI-разметке.
    private func assertShareAvailability(
        source: TrackSource,
        contexts: [TrackMenuContext]
    ) {
        for context in contexts {
            XCTAssertTrue(
                TrackMenuActionAvailability.isAvailable(
                    .share,
                    source: source,
                    context: context
                ),
                "Для \(source) в \(context) должно быть доступно действие отправки"
            )
        }
    }

    /// Проверяет каноничную доступность переключателя без привязки к SwiftUI-меню.
    private func assertFavoriteAvailability(
        source: TrackSource,
        contexts: [TrackMenuContext]
    ) {
        for context in contexts {
            XCTAssertTrue(
                TrackMenuActionAvailability.isAvailable(
                    .toggleFavorite,
                    source: source,
                    context: context
                ),
                "Для \(source) в \(context) должно быть доступно действие избранного"
            )
        }
    }
}

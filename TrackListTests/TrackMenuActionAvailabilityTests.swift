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
}

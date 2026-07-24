//
//  LibraryPresentationTextTests.swift
//  TrackListTests
//
//  Проверки presentation-заголовков экранов треков музыкальной коллекции.
//
//  Created by Pavel Fomin on 24.07.2026.
//

import XCTest
@testable import TrackList

/// Проверяет подготовку составного заголовка из типизированного источника списка треков.
final class LibraryPresentationTextTests: XCTestCase {
    /// Проверяет заголовок выбранного жанра.
    func testGenreNavigationTitlePresentation() {
        assertPresentation(
            for: .collectionValue(
                category: .genres,
                rawValue: "House",
                artistKey: nil
            ),
            title: "House",
            subtitle: String(localized: "Genre")
        )
    }

    /// Проверяет заголовок выбранного артиста.
    func testArtistNavigationTitlePresentation() {
        assertPresentation(
            for: .collectionValue(
                category: .artists,
                rawValue: "Daft Punk",
                artistKey: nil
            ),
            title: "Daft Punk",
            subtitle: String(localized: "Artist")
        )
    }

    /// Проверяет использование переданного артиста в подзаголовке альбома.
    func testAlbumNavigationTitlePresentationWithArtist() {
        assertPresentation(
            for: .collectionValue(
                category: .albums,
                rawValue: "Random Access Memories",
                artistKey: "Daft Punk"
            ),
            title: "Random Access Memories",
            subtitle: "Daft Punk"
        )
    }

    /// Проверяет резервную подпись альбома при отсутствующем или пустом артисте.
    func testAlbumNavigationTitlePresentationWithoutArtist() {
        let sources: [LibraryTrackListSource] = [
            .collectionValue(
                category: .albums,
                rawValue: "Random Access Memories",
                artistKey: nil
            ),
            .collectionValue(
                category: .albums,
                rawValue: "Random Access Memories",
                artistKey: "  \n "
            )
        ]

        for source in sources {
            assertPresentation(
                for: source,
                title: "Random Access Memories",
                subtitle: String(localized: "Album")
            )
        }
    }

    /// Проверяет заголовок выбранного года.
    func testYearNavigationTitlePresentation() {
        assertPresentation(
            for: .collectionValue(
                category: .years,
                rawValue: "2013",
                artistKey: nil
            ),
            title: "2013",
            subtitle: String(localized: "Year")
        )
    }

    /// Проверяет заголовок выбранного лейбла.
    func testLabelNavigationTitlePresentation() {
        assertPresentation(
            for: .collectionValue(
                category: .labels,
                rawValue: "Warp Records",
                artistKey: nil
            ),
            title: "Warp Records",
            subtitle: String(localized: "Label")
        )
    }

    /// Проверяет сохранение однострочного заголовка обычного общего списка треков.
    func testAllLibraryTracksKeepsExistingNavigationTitle() {
        let presentation = LibraryPresentationText.sourceNavigationTitlePresentation(
            for: .allLibraryTracks
        )

        XCTAssertEqual(presentation.title, String(localized: "Tracks"))
        XCTAssertNil(presentation.subtitle)
        XCTAssertEqual(
            LibraryPresentationText.sourceNavigationTitle(for: .allLibraryTracks),
            String(localized: "Tracks")
        )
    }

    /// Сравнивает все строки подготовленного заголовка с ожидаемыми значениями.
    private func assertPresentation(
        for source: LibraryTrackListSource,
        title: String,
        subtitle: String?
    ) {
        let presentation = LibraryPresentationText.sourceNavigationTitlePresentation(
            for: source
        )

        XCTAssertEqual(presentation.title, title)
        XCTAssertEqual(presentation.subtitle, subtitle)
    }
}

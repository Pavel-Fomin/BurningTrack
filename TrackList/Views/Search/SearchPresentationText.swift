//
//  SearchPresentationText.swift
//  TrackList
//
//  Локализованные подписи presentation-слоя поиска.
//
//  Created by Pavel Fomin on 21.07.2026.
//

import Foundation

/// Преобразует смысловые состояния поиска в локализованные подписи интерфейса.
enum SearchPresentationText {

    /// Возвращает короткую подпись фильтра совпадений.
    static func filterTitle(for field: TrackSearchMatchField?) -> String {
        guard let field else {
            return String(localized: "All")
        }

        switch field {
        case .tag(.title):
            return String(localized: "Title")
        case .tag(.artist):
            return String(localized: "Artist")
        case .tag(.album):
            return String(localized: "Album")
        case .tag(.genre):
            return String(localized: "Genre")
        case .tag(.year):
            return String(localized: "Year")
        case .tag(.publisher):
            return String(localized: "Label")
        case .tag(.comment):
            return String(localized: "Comment")
        case .fileName:
            return String(localized: "Filename")
        }
    }

    /// Возвращает полный заголовок режима сортировки.
    static func sortTitle(for mode: SearchSortMode) -> String {
        switch mode {
        case .artistAsc:
            return String(localized: "Artist A–Z")
        case .artistDesc:
            return String(localized: "Artist Z–A")
        case .titleAsc:
            return String(localized: "Title A–Z")
        case .titleDesc:
            return String(localized: "Title Z–A")
        case .albumAsc:
            return String(localized: "Album A–Z")
        case .albumDesc:
            return String(localized: "Album Z–A")
        case .yearNewest:
            return String(localized: "Year: Newest First")
        case .yearOldest:
            return String(localized: "Year: Oldest First")
        case .labelAsc:
            return String(localized: "Label A–Z")
        case .labelDesc:
            return String(localized: "Label Z–A")
        case .genreAsc:
            return String(localized: "Genre A–Z")
        case .genreDesc:
            return String(localized: "Genre Z–A")
        case .commentAsc:
            return String(localized: "Comment")
        case .filenameAsc:
            return String(localized: "Filename A–Z")
        case .filenameDesc:
            return String(localized: "Filename Z–A")
        case .dateNewest:
            return String(localized: "Date: Newest First")
        case .dateOldest:
            return String(localized: "Date: Oldest First")
        }
    }

    /// Возвращает короткую подпись режима во вложенном меню сортировки.
    static func groupedSortTitle(for mode: SearchSortMode) -> String {
        switch mode {
        case .artistAsc,
             .titleAsc,
             .albumAsc,
             .labelAsc,
             .genreAsc,
             .filenameAsc:
            return String(localized: "A–Z")
        case .artistDesc,
             .titleDesc,
             .albumDesc,
             .labelDesc,
             .genreDesc,
             .filenameDesc:
            return String(localized: "Z–A")
        case .commentAsc:
            return String(localized: "Comment")
        case .yearNewest,
             .dateNewest:
            return String(localized: "Newest First")
        case .yearOldest,
             .dateOldest:
            return String(localized: "Oldest First")
        }
    }

    /// Возвращает заголовок группы вложенного меню сортировки.
    static func sortGroupTitle(for group: SearchSortModeGroup) -> String {
        switch group.kind {
        case .artist:
            return String(localized: "Artist")
        case .title:
            return String(localized: "Title")
        case .album:
            return String(localized: "Album")
        case .year:
            return String(localized: "Year")
        case .label:
            return String(localized: "Label")
        case .genre:
            return String(localized: "Genre")
        case .comment:
            return String(localized: "Comment")
        case .fileName:
            return String(localized: "Filename")
        case .date:
            return String(localized: "Date")
        }
    }

    /// Возвращает подписи общих действий строки трека в контексте поиска.
    static var trackActionLabels: TrackActionMenuLabels {
        TrackActionMenuLabels(
            trackInfo: String(localized: "Track Info"),
            move: String(localized: "Move"),
            addToPlayer: String(localized: "Add to Player"),
            addToTracklist: String(localized: "Add to Tracklist"),
            tags: String(localized: "Tags"),
            fileName: String(localized: "File Name"),
            edit: String(localized: "Edit")
        )
    }

    static var searchFailedMessage: String {
        String(localized: "toast.search.failed")
    }
}

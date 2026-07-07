//
//  SearchScreenState.swift
//  TrackList
//
//  Состояние экрана поиска.
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation
import UIKit

// Тип контента, который должен показать экран поиска.
enum SearchContentState: Equatable {
    case emptyQuery
    case loading
    case results
    case noResults
}

// Строка найденного треклиста хранит результат поиска и готовые подписи UI.
struct SearchTrackListRowState: Identifiable, Equatable {
    let result: SearchTrackListResult
    let title: String
    let createdAtText: String
    let tracksCountText: String

    /// Идентификатор строки совпадает с id треклиста.
    var id: UUID {
        result.id
    }
}

// Строка найденного трека хранит готовые данные отображения из SQLite и runtime snapshot.
struct SearchTrackRowState: Identifiable {
    let result: SearchTrackResult
    let artwork: UIImage?
    let title: String?
    let artist: String?
    let duration: Double?
    let trackListNames: [String]?
    let showsFileFormat: Bool

    /// Идентификатор строки совпадает с id найденного трека.
    var id: UUID {
        result.id
    }
}

// Готовое состояние View без доменной логики внутри SwiftUI.
struct SearchScreenState {
    let query: String
    let folders: [SearchFolderResult]
    let trackLists: [SearchTrackListRowState]
    let tracks: [SearchTrackRowState]
    /// Готовые чипы фильтрации треков по полям совпадений.
    let trackFilterChips: [TrackSearchFilterChip]
    /// Выбранное поле фильтра или nil для режима "Все".
    let selectedTrackFilterField: TrackSearchMatchField?
    let contentState: SearchContentState
}

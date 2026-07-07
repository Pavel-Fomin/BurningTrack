//
//  SearchAction.swift
//  TrackList
//
//  Пользовательские действия раздела поиска.
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

enum SearchAction: Equatable {
    case appeared
    case queryChanged(String)
    case clearQuery
    case selectTrackFilter(TrackSearchMatchField?)
    case selectSortMode(SearchSortMode)
    case requestTrackSnapshot(UUID)
    case playTrack(SearchTrackResult)
    case openFolder(SearchFolderResult)
    case openTrackList(SearchTrackListResult)
    case showDetails(SearchTrackResult)
    case moveToFolder(SearchTrackResult)
    case addToPlayer(UUID)
    case addToTrackList(SearchTrackResult)
    case renameFile(SearchTrackResult, FileRenameStrategy)
    case editTags(SearchTrackResult)
}

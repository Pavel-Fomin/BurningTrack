//
//  TrackListsScreenStateBuilder.swift
//  TrackList
//
//  Собирает состояние экрана списка треклистов.
//
//  Created by Pavel Fomin on 15.06.2026.
//

import Foundation

struct TrackListsScreenStateBuilder {
    func build(
        trackLists: [TrackList],
        selectedSortMode: TrackListsSortMode?
    ) -> TrackListsScreenState {

        let rows = trackLists.map { trackList in
            TrackListsRowState(
                id: trackList.id,
                trackList: trackList,
                title: trackList.name,
                createdAt: trackList.createdAt,
                tracksCount: trackList.tracks.count
            )
        }

        return TrackListsScreenState(
            rows: rows,
            pendingDeleteTrackListId: nil,
            isShowingDeleteConfirmation: false,
            selectedSortMode: selectedSortMode
        )
    }
}

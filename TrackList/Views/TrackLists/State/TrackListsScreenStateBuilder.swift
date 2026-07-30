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
                title: TrackListPresentationText.title(
                    for: trackList.kind,
                    storedName: trackList.name
                ),
                createdAt: trackList.createdAt,
                tracksCount: trackList.tracks.count,
                canDelete: trackList.kind.canDelete,
                canReorder: trackList.kind.canReorder
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

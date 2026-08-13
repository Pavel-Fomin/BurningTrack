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
                title: TrackListPresentationText.title(
                    for: trackList.kind,
                    storedName: trackList.name
                ),
                createdAtText: TrackListPresentationText.createdAt(
                    for: trackList.kind,
                    date: trackList.createdAt
                ),
                tracksCountText: TrackListPresentationText.trackCount(
                    trackList.tracks.count
                ),
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

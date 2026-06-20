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
        trackLists: [TrackList]
    ) -> TrackListsScreenState {

        let rows = trackLists.map { trackList in
            TrackListsRowState(
                id: trackList.id,
                trackList: trackList,
                title: trackList.name,
                tracksCountText: "\(trackList.tracks.count) треков"
            )
        }

        return TrackListsScreenState(
            rows: rows,
            pendingDeleteTrackListId: nil,
            isShowingDeleteConfirmation: false
        )
    }
}

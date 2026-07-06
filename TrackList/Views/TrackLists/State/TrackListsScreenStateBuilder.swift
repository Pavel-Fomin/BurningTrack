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

    /// Форматирует дату создания треклиста без времени.
    private let createdAtFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    func build(
        trackLists: [TrackList],
        selectedSortMode: TrackListsSortMode?
    ) -> TrackListsScreenState {

        let rows = trackLists.map { trackList in
            TrackListsRowState(
                id: trackList.id,
                trackList: trackList,
                title: trackList.name,
                createdAtText: createdAtFormatter.string(from: trackList.createdAt),
                tracksCountText: "\(trackList.tracks.count) треков"
            )
        }

        return TrackListsScreenState(
            rows: rows,
            pendingDeleteTrackListId: nil,
            isShowingDeleteConfirmation: false,
            selectedSortMode: selectedSortMode,
            sortModeCaption: selectedSortMode?.caption
        )
    }
}

//
//  NewTrackListSelectionStateBuilder.swift
//  TrackList
//
//  Собирает состояние sheet-flow выбора треков для создания или пополнения треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
struct NewTrackListSelectionStateBuilder {
    /// Собирает состояние выбора треков.
    func build(
        folders: [LibraryFolder],
        selectedTrackIDs: Set<UUID>,
        isSubmitting: Bool
    ) -> NewTrackListSelectionState {
        NewTrackListSelectionState(
            folders: folders,
            selectedCount: selectedTrackIDs.count,
            selectedTrackIDs: selectedTrackIDs,
            canSubmit: selectedTrackIDs.isEmpty == false && !isSubmitting,
            isSubmitting: isSubmitting
        )
    }
}

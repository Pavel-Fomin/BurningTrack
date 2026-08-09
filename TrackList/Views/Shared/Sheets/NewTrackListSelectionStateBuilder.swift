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
        selectedCount: Int,
        isSubmitting: Bool
    ) -> NewTrackListSelectionState {
        return NewTrackListSelectionState(
            folders: folders,
            selectedCount: selectedCount,
            canSubmit: selectedCount > 0 && !isSubmitting,
            isSubmitting: isSubmitting
        )
    }
}

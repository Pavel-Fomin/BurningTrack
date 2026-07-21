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
    func build(selectedCount: Int) -> NewTrackListSelectionState {
        return NewTrackListSelectionState(
            canSubmit: selectedCount > 0
        )
    }
}

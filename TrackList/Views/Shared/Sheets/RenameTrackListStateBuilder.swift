//
//  RenameTrackListStateBuilder.swift
//  TrackList
//
//  Собирает состояние sheet-flow переименования треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
struct RenameTrackListStateBuilder {
    /// Собирает состояние формы переименования треклиста.
    func build(name: String) -> RenameTrackListState {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        return RenameTrackListState(
            name: name,
            canSubmit: !trimmedName.isEmpty
        )
    }
}

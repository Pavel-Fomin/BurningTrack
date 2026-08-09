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
    func build(
        name: String,
        currentName: String,
        isSubmitting: Bool
    ) -> RenameTrackListState {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCurrentName = currentName.trimmingCharacters(in: .whitespacesAndNewlines)

        return RenameTrackListState(
            name: name,
            canSubmit: !trimmedName.isEmpty
                && trimmedName != trimmedCurrentName
                && !isSubmitting,
            isSubmitting: isSubmitting
        )
    }
}

//
//  CreateTrackListStateBuilder.swift
//  TrackList
//
//  Собирает состояние sheet-flow создания треклиста.
//
//  Created by Pavel Fomin on 20.06.2026.
//

import Foundation

@MainActor
struct CreateTrackListStateBuilder {
    /// Собирает состояние формы создания треклиста.
    func build(name: String) -> CreateTrackListState {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        return CreateTrackListState(
            name: name,
            canSubmit: !trimmedName.isEmpty
        )
    }
}

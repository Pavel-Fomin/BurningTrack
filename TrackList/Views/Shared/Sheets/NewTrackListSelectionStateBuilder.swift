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
        selectedCount: Int,
        mode: NewTrackListSelectionMode
    ) -> NewTrackListSelectionState {
        let buttonTitle: String

        switch mode {
        case .create, .append:
            // Текущий UI показывает одинаковый текст кнопки для обоих режимов.
            buttonTitle = "Добавить"
        }

        return NewTrackListSelectionState(
            canSubmit: selectedCount > 0,
            buttonTitle: buttonTitle
        )
    }
}

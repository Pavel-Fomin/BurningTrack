//
//  SaveTrackListStateBuilder.swift
//  TrackList
//
//  Собирает presentation-состояние sheet-flow сохранения очереди плеера.
//
//  Created by Pavel Fomin on 04.08.2026.
//

import Foundation

/// Преобразует введённое имя и состояние выполнения в готовое состояние формы.
@MainActor
struct SaveTrackListStateBuilder {
    /// Собирает состояние формы, не изменяя отображаемый пользователю текст.
    func build(
        name: String,
        isSubmitting: Bool
    ) -> SaveTrackListState {
        let normalizedName = normalized(name)

        return SaveTrackListState(
            name: name,
            canSubmit: !normalizedName.isEmpty && !isSubmitting,
            isSubmitting: isSubmitting
        )
    }

    /// Нормализует имя для валидации и доменной команды.
    func normalized(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

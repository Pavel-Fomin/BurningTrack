//
//  View+ButtonStyles.swift
//  TrackList
//
//  Универсальные стили кнопок для всего приложения
//  Используются через .primaryButtonStyle(), .secondaryButtonStyle(), .destructiveButtonStyle()
//
//  Created by Pavel Fomin on 05.11.2025.
//

import SwiftUI

extension View {

    /// Основная кнопка (например, "Сохранить", "Добавить")
    func primaryButtonStyle() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }

    /// Второстепенная кнопка (например, "Отмена", "Закрыть")
    func secondaryButtonStyle() -> some View {
        self
            .buttonStyle(.bordered)
            .controlSize(.large)
    }

    /// Опасная кнопка (например, "Удалить", "Очистить")
    func destructiveButtonStyle() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .controlSize(.large)
    }
}

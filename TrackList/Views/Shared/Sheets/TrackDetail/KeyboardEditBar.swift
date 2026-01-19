//
//  KeyboardEditBar.swift
//  TrackList
//
//  Floating-панель действий для режимов inline-редактирования,отображаемая над системной клавиатурой.
//
//  Используется для подтверждения или отмены изменений без сдвига основного контента.
//
//  Не содержит бизнес-логики:
//  - не управляет фокусом
//  - не закрывает клавиатуру
//  - не знает контекст редактирования
//
//  Предназначена для повторного использования в разных экранах, где требуется UI поверх клавиатуры.
//
//  Created by PavelFomin on 19.01.2026.
//

import Foundation
import SwiftUI

struct KeyboardEditBar: View {

    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack {
            Button("Отмена", action: onCancel)
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer()

            Button("Сохранить", action: onDone)
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .padding(.horizontal, 16)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.56),
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.00)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                )
        )
        .shadow(
            color: .black.opacity(0.08),
            radius: 6,
            y: 4
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
    }
}

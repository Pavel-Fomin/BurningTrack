//
//  BatchFilenameRenameRow.swift
//  TrackList
//
//  Строка файла для feature массового переименования.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI

/// Leaf-строка показывает уже подготовленную presentation-модель без domain-зависимостей.
struct BatchFilenameRenameRow: View {
    /// Готовые данные одной строки Batch Filename Rename.
    let state: BatchFilenameRenameScreenState.Row
    /// Доступность исключения задаётся feature state, а не локальным View-условием.
    let isRemovalEnabled: Bool
    /// Typed-действие исключения строки передаётся контейнеру.
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(state.fileName)
                    .font(.body)
                    .lineLimit(1)

                if let statusDescription = state.statusDescription {
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundStyle(statusColor)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary.opacity(0.7))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .disabled(!isRemovalEnabled)
            .accessibilityLabel(String(localized: "Remove"))
        }
        .contentShape(Rectangle())
    }

    /// Преобразует готовый стиль state в системный цвет, не читая domain-статус.
    private var statusColor: Color {
        switch state.statusStyle {
        case .neutral: return .secondary
        case .success: return .green
        case .error: return .red
        }
    }
}

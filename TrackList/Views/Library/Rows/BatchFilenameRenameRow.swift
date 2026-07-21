//
//  BatchFilenameRenameRow.swift
//  TrackList
//
//  Строка файла для массового переименования.
//
//  Created by Pavel Fomin on 22.05.2026.
//

import SwiftUI

/// Визуальный стиль подписи статуса массового переименования.
enum BatchFilenameRenameRowStatusStyle {
    case neutral
    case success
    case error

    /// Цвет подписи статуса.
    var color: Color {
        switch self {
        case .neutral:
            return .secondary
        case .success:
            return .green
        case .error:
            return .red
        }
    }
}

/// Строка файла в sheet массового переименования.
///
/// Компонент отвечает только за отображение:
/// - имени файла;
/// - статуса под именем;
/// - кнопки исключения файла из операции.
///
/// Реальное переименование и состояние операции находятся во ViewModel.
struct BatchFilenameRenameRow: View {

    // MARK: - Input

    let fileName: String
    let statusDescription: String?
    let statusStyle: BatchFilenameRenameRowStatusStyle
    let onRemove: () -> Void

    // MARK: - UI

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(fileName)
                    .font(.body)
                    .lineLimit(1)

                if let statusDescription {
                    Text(statusDescription)
                        .font(.caption)
                        .foregroundStyle(statusStyle.color)
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
            .accessibilityLabel(String(localized: "Remove"))
        }
        .contentShape(Rectangle())
    }
}

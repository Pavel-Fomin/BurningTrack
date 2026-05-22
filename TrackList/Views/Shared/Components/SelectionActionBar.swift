//
//  SelectionActionBar.swift
//  TrackList
//
//  Нижняя плавающая панель действий для режима выбора.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI

struct SelectionActionBar: View {

    /// Форма glass-панели, общая для эффекта, обрезки и hit-test зоны.
    private let actionBarShape = RoundedRectangle(cornerRadius: 28, style: .continuous)

    // MARK: - Input

    let title: String
    let subtitle: String?
    let primaryTitle: String
    let iconName: String?
    let isPrimaryEnabled: Bool
    let onPrimaryTap: () -> Void

    // MARK: - UI

    var body: some View {
        HStack(spacing: 12) {

            // Иконка опциональна, чтобы компонент не был привязан к трекам или фонотеке.
            if let iconName {
                Circle()
                    .fill(Color.white.opacity(0.14))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: iconName)
                            .foregroundColor(.white.opacity(0.86))
                    }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.68))

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(primaryTitle) {
                onPrimaryTap()
            }
            .font(.headline)
            .foregroundColor(isPrimaryEnabled ? .white : .white.opacity(0.38))
            .disabled(!isPrimaryEnabled)
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .background {
            actionBarShape
                .fill(Color.black.opacity(0.72))
        }
        .glassEffect(.regular, in: actionBarShape)
        .clipShape(actionBarShape)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

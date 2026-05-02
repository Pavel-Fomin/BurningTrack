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

    // MARK: - Input

    let selectedCount: Int
    let title: String
    let subtitle: String?
    let primaryTitle: String
    let isPrimaryEnabled: Bool
    let onPrimaryTap: () -> Void

    // MARK: - UI

    var body: some View {
        HStack(spacing: 12) {

            Circle()
                .fill(Color.gray.opacity(0.18))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let subtitle {
                    Text(subtitle)
                        .font(.headline)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(primaryTitle) {
                onPrimaryTap()
            }
            .font(.headline)
            .disabled(!isPrimaryEnabled)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(radius: 18, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

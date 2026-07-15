//
//  LibraryFolderRowView.swift
//  TrackList
//
//  Общий внешний вид строки папки фонотеки.
//  Created by Pavel Fomin on 07.07.2026.
//

import SwiftUI

struct LibraryFolderRowView: View {
    let name: String
    let isAttaching: Bool
    let showsDisclosureIndicator: Bool
    let onTap: () -> Void

    init(
        name: String,
        isAttaching: Bool = false,
        showsDisclosureIndicator: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.name = name
        self.isAttaching = isAttaching
        self.showsDisclosureIndicator = showsDisclosureIndicator
        self.onTap = onTap
    }

    var body: some View {
        Button {
            guard isAttaching == false else { return }
            onTap()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(name)
                    .lineLimit(1)

                Spacer()

                trailingAccessory
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isAttaching)
    }

    /// Правая часть строки совпадает с режимами фонотеки: прогресс attach или переход в подпапку.
    @ViewBuilder
    private var trailingAccessory: some View {
        if isAttaching {
            ProgressView()
                .controlSize(.small)
        } else if showsDisclosureIndicator {
            Image(systemName: "chevron.right")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }
}

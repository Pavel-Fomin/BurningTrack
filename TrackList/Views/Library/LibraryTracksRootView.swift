//
//  LibraryTracksRootView.swift
//  TrackList
//
//  Корневой экран режима "Треки" со строками навигации.
//
//  Created by Pavel Fomin on 10.07.2026.
//

import SwiftUI

struct LibraryTracksRootView: View {
    // MARK: - Входные данные

    /// Строки корневого списка в явном порядке.
    let rootItems: [LibraryCollectionRootItemState]
    /// Передаёт выбор строки корневого списка контейнеру фонотеки.
    let onRootItemSelected: (LibraryCollectionRootItem) -> Void

    // MARK: - UI

    var body: some View {
        List(rootItems) { itemState in
            Button {
                onRootItemSelected(itemState.item)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: itemState.item.systemImage)
                        .foregroundColor(.blue)
                        .frame(width: 24)

                    Text(itemState.item.title)
                        .lineLimit(1)

                    Spacer()

                    // Ноль является готовым значением и отображается наравне с остальными числами.
                    if let count = itemState.count {
                        Text("\(count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowSeparator(
                itemState.id == rootItems.first?.id ? .hidden : .automatic,
                edges: .top
            )
            .listRowSeparator(
                itemState.id == rootItems.last?.id ? .hidden : .automatic,
                edges: .bottom
            )
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

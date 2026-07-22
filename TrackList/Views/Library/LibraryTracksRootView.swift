//
//  LibraryTracksRootView.swift
//  TrackList
//
//  Строки секции коллекции корневого экрана фонотеки.
//
//  Created by Pavel Fomin on 10.07.2026.
//

import SwiftUI

struct LibraryTracksRootView: View {
    // MARK: - Входные данные

    /// Строки секции коллекции в явном порядке.
    let rootItems: [LibraryCollectionRootItemState]
    /// Передаёт выбор строки корневого списка контейнеру фонотеки.
    let onRootItemSelected: (LibraryCollectionRootItem) -> Void

    // MARK: - Геометрия

    private enum Layout {
        /// Соответствует скруглению карточек категорий в согласованном макете.
        static let itemCornerRadius: CGFloat = 26
    }

    /// Две равные колонки сохраняют компактное представление шести разделов коллекции.
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    // MARK: - UI

    var body: some View {
        // Исходный порядок rootItems задаёт Presenter и сохраняется при раскладке в две колонки.
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(rootItems) { itemState in
                collectionItem(itemState)
            }
        }
        // Сетка использует всю ширину строки List; ширину карточек определяют только гибкие колонки.
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    /// Строит компактную системную кнопку раздела без изменения данных и маршрута коллекции.
    private func collectionItem(
        _ itemState: LibraryCollectionRootItemState
    ) -> some View {
        Button {
            onRootItemSelected(itemState.item)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: itemState.item.systemImage)
                    .foregroundColor(.accentColor)

                Text(LibraryPresentationText.collectionRootItemTitle(for: itemState.item))
                    // При крупном Dynamic Type название может занять несколько строк вместо обрезания.
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Spacer(minLength: 0)

                // Ноль является готовым значением и отображается наравне с остальными числами.
                if let count = itemState.count {
                    Text("\(count)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                }
            }
            .font(.body)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Layout.itemCornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

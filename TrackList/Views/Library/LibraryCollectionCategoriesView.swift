//
//  LibraryCollectionCategoriesView.swift
//  TrackList
//
//  Список разделов музыкальной коллекции.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI

struct LibraryCollectionCategoriesView: View {
    // MARK: - Входные данные

    /// Разделы коллекции, которые нужно показать в текущем режиме корня.
    let categories: [LibraryCollectionCategory]
    /// Передаёт выбранный раздел наружу, не выполняя навигацию внутри view.
    let onCategorySelected: (LibraryCollectionCategory) -> Void

    // MARK: - UI

    var body: some View {
        List(categories) { category in
            LibraryCollectionCategoryRowView(
                category: category,
                onCategorySelected: onCategorySelected
            )
        }
    }
}

/// Строка раздела музыкальной коллекции, используемая в списке категорий и корне режима "Треки".
struct LibraryCollectionCategoryRowView: View {
    /// Раздел коллекции, который нужно показать.
    let category: LibraryCollectionCategory
    /// Передаёт выбор раздела владельцу навигации.
    let onCategorySelected: (LibraryCollectionCategory) -> Void

    var body: some View {
        Button {
            onCategorySelected(category)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.systemImage)
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(category.title)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

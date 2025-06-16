//
//  TrackListChipsGroupView.swift
//  TrackList
//
//  Группа чип-вью для отображения и редактирования треклистов
//
//  Created by Pavel Fomin on 21.05.2025.
//

import SwiftUI

// MARK: - Группа чипсов (плейлистов)
struct TrackListChipsGroupView: View {
    let trackLists: [TrackList]           // Все доступные треклисты
    let selectedId: UUID                  // ID выбранного треклиста
    let isEditing: Bool                   // Активен режим редактирования

    // MARK: - Обработчики действий
    let onSelect: (UUID) -> Void           // Выбор треклиста
    let onAddFromContextMenu: () -> Void   // Добавление треков в список
    let onDelete: (UUID) -> Void           // Удаление треклиста
    let onDoneEditing: () -> Void          // Выход из режима редактирования
    let onRename: () -> Void               // Переименование треклиста

    var body: some View {
        HStack(spacing: 8) {
            editingButtonIfNeeded          // Кнопка "Готово" при редактировании
            chipsList                      // Список чипсов
        }
        .animation(.chipEditMode, value: isEditing)
    }

    // MARK: - Кнопка "Готово"
    private var editingButtonIfNeeded: some View {
        Group {
            if isEditing {
                Button(action: {
                    withAnimation(.chipEditMode) {
                        onDoneEditing()
                    }
                }) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
            }
        }
    }

    // MARK: - Список чипсов
    @ViewBuilder
    var chipsList: some View {
        ForEach(trackLists) { trackList in
            animatedChipView(for: trackList)
        }
    }

    // MARK: - Один чип с анимацией
    @ViewBuilder
    private func animatedChipView(for trackList: TrackList) -> some View {
        TrackListChipView(
            trackList: trackList,
            isSelected: trackList.id == selectedId,
            isEditing: isEditing,
            onSelect: { onSelect(trackList.id) },
            onAdd: onAddFromContextMenu,
            onDelete: { onDelete(trackList.id) },
            onEdit: onRename
        )
        .id(trackList.id)
    }
}

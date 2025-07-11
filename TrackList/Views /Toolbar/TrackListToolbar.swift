//
//  TrackListToolbar.swift
//  TrackList
//
//  Тулбар раздела "Треклист"
//
//  Created by Pavel Fomin on 16.05.2025.
//

import SwiftUI

// MARK: - Тулбар над списком треклистов

struct TrackListToolbar: View {
    let isEditing: Bool               // Текущий режим редактирования
    let hasTrackLists: Bool           // Есть ли плейлисты для редактирования
    let onAdd: () -> Void             // Обработчик нажатия на "+"
    let onToggleEditMode: () -> Void  // Обработчик переключения режима

    var body: some View {
        HStack {
            
            // Заголовок
            Text("ПЛЕЕР")
                .font(.system(size: 28, weight: .heavy))
                .foregroundColor(.primary)
                .padding(.top, 4)

            Spacer()

            // Кнопка переключения режима редактирования (если есть плейлисты)
            if hasTrackLists {
                Button(action: onToggleEditMode) {
                    Image(systemName: "wand.and.sparkles.inverse")
                        .font(.title2)
                }
            }

            // Кнопка добавления нового треклиста
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.title2)
                    .padding(.leading, 12)
            }
        }
    }
}

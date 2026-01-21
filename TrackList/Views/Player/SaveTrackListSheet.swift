//
//  SaveTrackListSheet.swift
//  TrackList
//
//  Экран создания нового треклиста.
//  Чистая UI-форма ввода имени.
//
//  ВАЖНО:
//  - НЕ содержит навигации, тулбара и кнопок
//  - НЕ содержит бизнес-логики (сохранение, закрытие и т.п.)
//  - Используется ТОЛЬКО как визуальный слой
//  - Всё управление состоянием и действиями находится в контейнере
//
//  Created by Pavel Fomin on 11.07.2025.
//

import SwiftUI

struct SaveTrackListSheet: View {

    // MARK: - Input

    @Binding var name: String                   /// Название треклиста. Источник  в SaveTrackListContainer. Получает значение через Binding и не владеет состоянием.
    @FocusState private var isNameFocused: Bool /// Управление фокусом. Используется для автоматического показа клавиатуры при открытии

    // MARK: - UI

    var body: some View {
        Form {
            Section {
                TextField("Название", text: $name)
                    .clearable($name)
                    .focused($isNameFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
            }
        }
        .formStyle(.grouped)

        /// Автоматически устанавливаем фокус при появлении шита,
        /// чтобы сразу открыть клавиатуру без дополнительного тапа.
        .task {
            isNameFocused = true
        }
    }
}

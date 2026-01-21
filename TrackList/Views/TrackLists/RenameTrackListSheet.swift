//
//  RenameTrackListSheet.swift
//  TrackList
//
//  UI-форма для ввода нового имени треклиста.
//
//  Роль компонента:
//  - отображает поле ввода имени
//  - управляет фокусом TextField
//  - не содержит бизнес-логики и навигации
//
//  Архитектурные принципы:
//  - не знает о SheetManager
//  - не знает о командах сохранения
//  - не управляет закрытием sheet’а
//  - используется только внутри RenameTrackListContainer
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct RenameTrackListSheet: View {

    // MARK: - Input

    /// Связанное состояние имени треклиста.
    /// Источник истины находится в контейнере.
    @Binding var name: String

    /// Состояние фокуса поля ввода.
    /// Используется для автоматического показа клавиатуры.
    @FocusState private var isNameFocused: Bool

    // MARK: - UI

    var body: some View {
        Form {
            Section {
                TextField("Новое название", text: $name)
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

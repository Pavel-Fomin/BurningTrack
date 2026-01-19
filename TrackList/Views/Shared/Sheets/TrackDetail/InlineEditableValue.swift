//
//  InlineEditableValue.swift
//  TrackList
//
//  UI-компонент inline-редактирования значения поля
//  Меняет ТОЛЬКО нижнюю часть строки (value)
//  Не содержит логики сохранения
//
//  Created by PavelFomin on 19.01.2026.
//

import SwiftUI

struct InlineEditableValue: View {

    let field: EditableTrackField
    @Binding var value: String

    let isEditing: Bool
    let onBeginEditing: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        Group {
            if isEditing {
                editor
            } else {
                Text(value.isEmpty ? "—" : value)
                    .foregroundStyle(value.isEmpty ? .secondary : .primary)
                    .onTapGesture {
                        onBeginEditing()
                        isFocused = true
                    }
            }
        }
        .animation(.default, value: isEditing)
    }

    @ViewBuilder
    private var editor: some View {
        switch field.kind {

        case .text(let multiline):
            if multiline {
                TextEditor(text: $value)
                    .focused($isFocused)
                    .frame(minHeight: 44)
                    /// Автокорректировка
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .textContentType(.none)

            } else {
                TextField("", text: $value)
                    .focused($isFocused)
                    /// Автокорректировка
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    .textContentType(.none)
            }

        case .number:
            TextField("", text: $value)
                .focused($isFocused)
                .keyboardType(.numberPad)
                /// Автокорректировка
                .autocorrectionDisabled(true)
                .textContentType(.none)
        }
    }
}

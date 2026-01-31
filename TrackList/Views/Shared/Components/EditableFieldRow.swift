//
//  EditableFieldRow.swift
//  TrackList
//
//  Универсальная строка редактирования поля(Contacts-style).
//
//  Роль:
//  - отображает одно редактируемое поле
//  - лейбл визуально находится внутри инпута
//  - поддерживает однострочный и многострочный ввод
//
//  Архитектура:
//  - не знает о треке, тегах, контейнерах
//  - работает только с Binding<String>
//  - переиспользуемый UI-компонент
//
//  Created by Pavel Fomin on 27.01.2026.
//

import SwiftUI

struct EditableFieldRow: View {

    // MARK: - Input

    let title: String       /// Текст лейбла
    let isMultiline: Bool   /// Режим ввода
    
    @Binding var value: String /// Значение поля

    // MARK: - UI

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            // Лейбл внутри карточки
            Text(title.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)

            if isMultiline {
                multilineInput
            } else {
                singleLineInput
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(background)
    }

    // MARK: - Single line

    private var singleLineInput: some View {
        TextField("", text: $value)
            .font(.body)
            .foregroundColor(.primary)
    }

    // MARK: - Multiline

    private var multilineInput: some View {
        TextEditor(text: $value)
            .font(.body)
            .foregroundColor(.primary)
            .frame(minHeight: 80)
            .scrollContentBackground(.hidden)
    }

    // MARK: - Background

    private var background: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }
}

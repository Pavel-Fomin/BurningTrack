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
import UIKit

struct EditableFieldRow: View {

    // MARK: - Input

    let title: String                /// Текст лейбла
    let isMultiline: Bool            /// Режим ввода
    let keyboardType: UIKeyboardType /// Тип клавиатуры
    let placeholder: String          /// Подсказка поля ввода
    let showsClearButton: Bool       /// Показывать кнопку очистки значения
    let onForceClear: (() -> Void)?  /// Принудительная очистка поля, когда value уже пустой, но визуально есть mixed-placeholder.
    
    @Binding var value: String /// Значение поля

    /// Опциональный фокус для внешнего управления конкретным полем.
    var focusBinding: FocusState<Bool>.Binding?

    init(
        title: String,
        isMultiline: Bool,
        keyboardType: UIKeyboardType,
        placeholder: String = "",
        value: Binding<String>,
        showsClearButton: Bool = false,
        onForceClear: (() -> Void)? = nil,
        focusBinding: FocusState<Bool>.Binding? = nil
    ) {
        self.title = title
        self.isMultiline = isMultiline
        self.keyboardType = keyboardType
        self.placeholder = placeholder
        self.showsClearButton = showsClearButton
        self.onForceClear = onForceClear
        self._value = value
        self.focusBinding = focusBinding
    }

    // MARK: - UI

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

            // Лейбл внутри карточки
            Text(title.uppercased())
                .font(.caption2)
                .foregroundColor(.secondary)

            inputRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(background)
    }

    /// Поле ввода с кнопкой очистки в trailing-части.
    private var inputRow: some View {
        Group {
            if isMultiline {
                multilineInput
            } else {
                singleLineInput
            }
        }
    }

    /// Кнопка очистки поля.
    private var clearButton: some View {
        Button {
            guard canClear else { return }
            if value.isEmpty {
                onForceClear?()
            } else {
                value = ""
            }
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.body)
                .foregroundStyle(canClear ? Color(.secondaryLabel) : Color(.quaternaryLabel))
                .frame(width: 28, height: 28, alignment: .trailing)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Single line

    private var singleLineInput: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .leading) {
                if value.isEmpty && !placeholder.isEmpty {
                    Text(placeholder)
                        .font(.body)
                        .foregroundStyle(placeholderColor)
                        .allowsHitTesting(false)
                }

                textField
            }
            .font(.body)
            .foregroundColor(.primary)
            .keyboardType(keyboardType)
            .frame(maxWidth: .infinity, alignment: .leading)

            clearButton
        }
    }

    /// Однострочное текстовое поле.
    private var textField: some View {
        Group {
            if let focusBinding {
                TextField("", text: $value)
                    .focused(focusBinding)
            } else {
                TextField("", text: $value)
            }
        }
    }

    // MARK: - Multiline

    private var multilineInput: some View {
        ZStack(alignment: .topTrailing) {
            TextEditor(text: $value)
                .font(.body)
                .foregroundColor(.primary)
                .frame(minHeight: 80)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollContentBackground(.hidden)

            clearButton
                .padding(.top, 2)
        }
    }

    // MARK: - Background

    private var background: some View {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground))
    }

    /// Можно ли очистить поле.
    private var canClear: Bool {
        !value.isEmpty || showsClearButton
    }

    /// Цвет подсказки поля ввода.
    private var placeholderColor: Color {
        placeholder == "Смешанно" ? .primary : .secondary
    }
}

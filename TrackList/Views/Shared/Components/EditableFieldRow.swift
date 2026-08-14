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

    // MARK: - Входные данные

    let title: String
    let isMultiline: Bool
    let keyboardType: UIKeyboardType
    let placeholder: String
    let emphasizesPlaceholder: Bool
    let showsClearButton: Bool
    /// Вызывается для очистки смешанной подсказки, когда связанное значение уже пусто.
    let onForceClear: (() -> Void)?
    
    @Binding var value: String

    /// Опциональный фокус для внешнего управления конкретным полем.
    var focusBinding: FocusState<Bool>.Binding?

    init(
        title: String,
        isMultiline: Bool,
        keyboardType: UIKeyboardType,
        placeholder: String = "",
        emphasizesPlaceholder: Bool = false,
        value: Binding<String>,
        showsClearButton: Bool = false,
        onForceClear: (() -> Void)? = nil,
        focusBinding: FocusState<Bool>.Binding? = nil
    ) {
        self.title = title
        self.isMultiline = isMultiline
        self.keyboardType = keyboardType
        self.placeholder = placeholder
        self.emphasizesPlaceholder = emphasizesPlaceholder
        self.showsClearButton = showsClearButton
        self.onForceClear = onForceClear
        self._value = value
        self.focusBinding = focusBinding
    }

    // MARK: - Интерфейс

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {

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
        .accessibilityLabel(SharedPresentationText.clearAccessibilityLabel)
    }

    // MARK: - Одна строка

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
                    .accessibilityLabel(title)
            } else {
                TextField("", text: $value)
                    .accessibilityLabel(title)
            }
        }
    }

    // MARK: - Многострочный ввод

    private var multilineInput: some View {
        ZStack(alignment: .topTrailing) {
            TextEditor(text: $value)
                .font(.body)
                .foregroundColor(.primary)
                .frame(minHeight: 80)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollContentBackground(.hidden)
                .accessibilityLabel(title)

            clearButton
                .padding(.top, 2)
        }
    }

    // MARK: - Фон

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
        emphasizesPlaceholder ? .primary : .secondary
    }
}

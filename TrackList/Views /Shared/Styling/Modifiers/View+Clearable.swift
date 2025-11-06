//
//  View+Clearable.swift
//  TrackList
//
//  Модификатор для добавления системной кнопки "×" в поля ввода
//  Используется через .clearable($text)
//  Добавляет иконку "×" для очистки текстового поля, аналог UITextField.clearButtonMode
//
//  Created by Pavel Fomin on 06.11.2025.
//

import SwiftUI

extension View {
    func clearable(_ text: Binding<String>) -> some View {
        self
            .overlay(alignment: .trailing) {
                if !text.wrappedValue.isEmpty {
                    Button {
                        text.wrappedValue = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .imageScale(.medium)
                            .padding(.trailing, 6)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Очистить текст")
                }
            }
    }
}

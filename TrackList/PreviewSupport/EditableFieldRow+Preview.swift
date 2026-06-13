//
//  EditableFieldRow+Preview.swift
//  TrackList
//
//  Xcode Preview для строки редактирования поля.
//
//  Created by Pavel Fomin on 13.06.2026.
//

#if DEBUG
import SwiftUI
import UIKit

/// Хранит локальное значение Binding только для интерактивного Preview.
private struct EditableFieldRowPreviewContainer: View {
    let title: String
    let isMultiline: Bool
    let placeholder: String

    @State private var value: String

    init(
        title: String,
        value: String,
        isMultiline: Bool = false,
        placeholder: String = ""
    ) {
        self.title = title
        self.isMultiline = isMultiline
        self.placeholder = placeholder
        self._value = State(initialValue: value)
    }

    var body: some View {
        VStack {
            EditableFieldRow(
                title: title,
                isMultiline: isMultiline,
                keyboardType: .default,
                placeholder: placeholder,
                value: $value
            )
            Spacer()
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Обычное значение — iPhone") {
    EditableFieldRowPreviewContainer(
        title: "Название трека",
        value: "Midnight Drive"
    )
}

#Preview("Пустое значение — iPhone") {
    EditableFieldRowPreviewContainer(
        title: "Исполнитель",
        value: "",
        placeholder: "Введите исполнителя"
    )
}

#Preview("Длинное значение — iPhone") {
    EditableFieldRowPreviewContainer(
        title: "Альбом",
        value: "Очень длинное название альбома для проверки поведения текстового поля на узком экране"
    )
}

#Preview("Многострочное значение — iPhone") {
    EditableFieldRowPreviewContainer(
        title: "Комментарий",
        value: "Первая строка комментария.\nВторая строка с дополнительной информацией.",
        isMultiline: true
    )
}

#Preview("Обычное значение — iPad") {
    EditableFieldRowPreviewContainer(
        title: "Название трека",
        value: "Northern Lights"
    )
}
#endif

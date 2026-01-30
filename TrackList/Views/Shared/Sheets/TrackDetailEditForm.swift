//
//  TrackDetailEditForm.swift
//  TrackList
//
//  Форма редактирования информации о треке (Contacts-style).
//
//  Роль:
//  - отображает форму редактирования тегов и имени файла
//  - использует EditableFieldRow как единственный UI-инпут
//  - не содержит логики сохранения или загрузки
//
//  Архитектура:
//  - данные приходят извне через Binding
//  - порядок и состав полей задаётся конфигурацией
//  - использует ЕДИНЫЙ EditableTrackField (доменный)
//  - не знает о контейнерах, TagLib и кнопке ✓
//
//  Created by Pavel Fomin on 27.01.2026.
//

import SwiftUI

struct TrackDetailEditForm: View {

    // MARK: - Bindings

    /// Имя файла (без расширения)
    @Binding var fileName: String

    /// Значения тегов (доменная модель)
    @Binding var values: [EditableTrackField: String]

    // MARK: - Field configuration

    private struct FieldConfig: Identifiable {
        let id: EditableTrackField
        let title: String
        let isMultiline: Bool
    }

    private let tagFields: [FieldConfig] = [
        .init(id: .title,  title: "Название трека", isMultiline: false),
        .init(id: .artist, title: "Исполнитель",   isMultiline: false),
        .init(id: .album,  title: "Альбом",        isMultiline: false),
        .init(id: .genre,  title: "Жанр",          isMultiline: false)
    ]

    private let commentField = FieldConfig(
        id: .comment,
        title: "Комментарий",
        isMultiline: true
    )

    // MARK: - UI

    var body: some View {
        List {

            // Название файла
            Section("НАЗВАНИЕ ФАЙЛА") {
                EditableFieldRow(
                    title: "Название файла",
                    isMultiline: false,
                    value: $fileName
                )
            }

            // Теги
            Section("ТЕГИ") {
                ForEach(tagFields) { field in
                    EditableFieldRow(
                        title: field.title,
                        isMultiline: field.isMultiline,
                        value: binding(for: field.id)
                    )
                }
            }

            // Комментарий
            Section("КОММЕНТАРИЙ") {
                EditableFieldRow(
                    title: commentField.title,
                    isMultiline: true,
                    value: binding(for: commentField.id)
                )
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Helpers

    private func binding(for field: EditableTrackField) -> Binding<String> {
        Binding(
            get: { values[field] ?? "" },
            set: { values[field] = $0 }
        )
    }
}

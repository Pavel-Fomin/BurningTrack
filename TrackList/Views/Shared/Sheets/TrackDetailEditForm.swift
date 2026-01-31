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

    @Binding var fileName: String
    @Binding var values: [EditableTrackField: String]

    // MARK: - Artwork

    let artworkUIImage: UIImage?

    // MARK: - Field configuration

    private struct FieldConfig: Identifiable {
        let id: EditableTrackField
        let title: String
        let isMultiline: Bool
    }

    private let fields: [FieldConfig] = [
        .init(id: .title,   title: "Название трека", isMultiline: false),
        .init(id: .artist,  title: "Исполнитель",   isMultiline: false),
        .init(id: .album,   title: "Альбом",        isMultiline: false),
        .init(id: .genre,   title: "Жанр",          isMultiline: false),
        .init(id: .comment, title: "Комментарий",   isMultiline: true)
    ]

    // MARK: - UI

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                artworkBlock

                EditableFieldRow(
                    title: "Название файла",
                    isMultiline: false,
                    value: $fileName
                )

                ForEach(fields) { field in
                    EditableFieldRow(
                        title: field.title,
                        isMultiline: field.isMultiline,
                        value: binding(for: field.id)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Artwork

    private var artworkBlock: some View {
        Group {
            if let artworkUIImage {
                Image(uiImage: artworkUIImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Helpers

    private func binding(for field: EditableTrackField) -> Binding<String> {
        Binding(
            get: { values[field] ?? "" },
            set: { values[field] = $0 }
        )
    }
}

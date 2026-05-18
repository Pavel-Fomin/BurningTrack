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
import PhotosUI

struct TrackDetailEditForm: View {

    // MARK: - Bindings

    @Binding var fileName: String
    @Binding var values: [EditableTrackField: String]

    // MARK: - Artwork

    let artworkUIImage: UIImage?

    @Binding var artworkEditState: ArtworkEditState

    @State private var selectedPhotoItem: PhotosPickerItem?

    /// Фокус поля имени файла для показа toolbar над клавиатурой.
    @FocusState private var isFileNameFocused: Bool

    // MARK: - Field configuration

    private struct FieldConfig: Identifiable {
        let id: EditableTrackField
        let title: String
        let isMultiline: Bool
    }

    private let fields: [FieldConfig] = [
        .init(id: .title,     title: "Название трека",   isMultiline: false),
        .init(id: .artist,    title: "Исполнитель",      isMultiline: false),
        .init(id: .album,     title: "Альбом",           isMultiline: false),
        .init(id: .genre,     title: "Жанр",             isMultiline: false),
        .init(id: .year,      title: "Год выпуска",      isMultiline: false),
        .init(id: .publisher, title: "Лейбл / издатель", isMultiline: false),
        .init(id: .comment,   title: "Комментарий",      isMultiline: true)
    ]

    // MARK: - Derived artwork UI

    /// Картинка, которую нужно показывать в форме прямо сейчас.
    ///
    /// Приоритет такой:
    /// 1. новая выбранная пользователем обложка
    /// 2. исходная обложка трека
    /// 3. отсутствие обложки
    private var previewArtworkUIImage: UIImage? {
        if let data = artworkEditState.newArtworkData,
           let image = UIImage(data: data) {
            return image
        }

        if artworkEditState.hasArtworkForPreview == false {return nil}
        return artworkUIImage
    }

    // MARK: - Derived file name

    private var normalizedArtist: String {
        (values[.artist] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedTitle: String {
        (values[.title] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canBuildFileNameFromTags: Bool {
        !normalizedArtist.isEmpty && !normalizedTitle.isEmpty
    }

    private var artistTitleFileName: String {
        "\(normalizedArtist) - \(normalizedTitle)"
    }

    private var titleArtistFileName: String {
        "\(normalizedTitle) - \(normalizedArtist)"
    }

    // MARK: - UI

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                artworkBlock

                EditableFieldRow(
                    title: "Название файла",
                    isMultiline: false,
                    keyboardType: .default,
                    value: $fileName,
                    focusBinding: $isFileNameFocused
                )

                ForEach(fields) { field in
                    EditableFieldRow(
                        title: field.title,
                        isMultiline: field.isMultiline,
                        keyboardType: field.id == .year ? .numberPad : .default,
                        value: binding(for: field.id)
                    )
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .task(id: selectedPhotoItem) {
            await loadSelectedArtwork()
        }
        .toolbar {
            if isFileNameFocused && canBuildFileNameFromTags {
                ToolbarItemGroup(placement: .keyboard) {
                    Button("Артист - Название") {
                        fileName = artistTitleFileName
                    }

                    Rectangle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 1, height: 18)

                    Button("Название - Артист") {
                        fileName = titleArtistFileName
                    }
                }
            }
        }
    }

    // MARK: - Artwork

    private var artworkBlock: some View {
        VStack(spacing: 12) {
            Group {
                if let previewArtworkUIImage {
                    Image(uiImage: previewArtworkUIImage)
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

            if artworkEditState.shouldShowRemoveButton {
                Button("Удалить") {
                    artworkEditState.removeArtwork()
                }
            }

            if artworkEditState.shouldShowAddButton {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Text("Добавить")
                }
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

    /// Загружает выбранное изображение из системного пикера
    /// и сохраняет его в локальное состояние формы.
    private func loadSelectedArtwork() async {
        guard let selectedPhotoItem else {return}
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) else {return}
        guard UIImage(data: data) != nil else {return}

        await MainActor.run {
            artworkEditState.setNewArtwork(data: data)
        }
    }
}

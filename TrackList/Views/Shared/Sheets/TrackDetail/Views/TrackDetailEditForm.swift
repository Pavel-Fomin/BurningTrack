//
//  TrackDetailEditForm.swift
//  TrackList
//
//  Action-based форма редактирования Track Detail.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import PhotosUI
import SwiftUI

/// Leaf View редактирования, не владеющий draft, artwork-state или командами записи.
struct TrackDetailEditForm: View {
    /// Готовое состояние формы.
    let state: TrackDetailScreenState
    /// Typed-действия, обрабатываемые ViewModel.
    let send: (TrackDetailAction) -> Void

    /// Системный выбор изображения остаётся presentation-состоянием View.
    @State private var selectedPhotoItem: PhotosPickerItem?
    /// Фокус имени файла управляет только keyboard toolbar.
    @FocusState private var isFileNameFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                artworkBlock

                EditableFieldRow(
                    title: TagEditorPresentationText.fileNameTitle,
                    isMultiline: false,
                    keyboardType: .default,
                    value: fileNameBinding,
                    focusBinding: $isFileNameFocused
                )

                ForEach(EditableTrackField.allCases, id: \.self) { field in
                    fieldEditor(for: field)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .disabled(state.isSaving)
        .task(id: selectedPhotoItem) {
            await submitSelectedArtwork()
        }
        .toolbar {
            if isFileNameFocused && state.canUseFileNameStrategies {
                ToolbarItemGroup(placement: .keyboard) {
                    Button(
                        FileRenamePresentationText.strategyTitle(
                            for: FileRenameStrategy.artistTitle
                        )
                    ) {
                        send(.fileNameStrategySelected(.artistTitle))
                    }

                    Rectangle()
                        .fill(Color.secondary.opacity(0.35))
                        .frame(width: 1, height: 18)

                    Button(
                        FileRenamePresentationText.strategyTitle(
                            for: FileRenameStrategy.titleArtist
                        )
                    ) {
                        send(.fileNameStrategySelected(.titleArtist))
                    }
                }
            }
        }
    }

    /// Связывает UI-инпут имени с typed action без прямой мутации ViewModel.
    private var fileNameBinding: Binding<String> {
        Binding(
            get: { state.fileName },
            set: { send(.fileNameChanged($0)) }
        )
    }

    /// Выводит shared field row и feature-local ошибку year.
    @ViewBuilder
    private func fieldEditor(
        for field: EditableTrackField
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            EditableFieldRow(
                title: TagEditorPresentationText.fieldTitle(for: field),
                isMultiline: field.isMultiline,
                keyboardType: field == .year ? .numberPad : .default,
                value: valueBinding(for: field)
            )

            if field == .year, let yearValidationMessage = state.yearValidationMessage {
                Text(yearValidationMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .accessibilityLabel(yearValidationMessage)
            }
        }
    }

    /// Связывает одно значение с соответствующим typed action.
    private func valueBinding(
        for field: EditableTrackField
    ) -> Binding<String> {
        Binding(
            get: { state.editableValues[field] ?? "" },
            set: { send(.fieldChanged(field, $0)) }
        )
    }

    /// Формирует artwork-блок только из готового presentation-состояния.
    private var artworkBlock: some View {
        VStack(spacing: 12) {
            ArtworkPreparationView(request: state.artwork.request) { image in
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 180, height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(radius: 8)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    )
            }

            if state.artwork.canRemoveArtwork {
                Button(TagEditorPresentationText.removeArtworkTitle) {
                    send(.artworkRemoveTapped)
                }
            }

            if state.artwork.canAddArtwork {
                PhotosPicker(
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text(TagEditorPresentationText.addArtworkTitle)
                }
            }
        }
        .padding(.vertical, 20)
        .accessibilityLabel(
            TagEditorPresentationText.artworkAccessibilityLabel(
                hasArtwork: state.artwork.request != nil
            )
        )
    }

    /// Загружает только bytes выбранного изображения и передаёт их в action flow.
    private func submitSelectedArtwork() async {
        guard let selectedPhotoItem else { return }
        guard let data = try? await selectedPhotoItem.loadTransferable(type: Data.self) else {
            return
        }

        guard !Task.isCancelled else { return }
        send(.artworkSelected(data: data, revision: UUID()))
    }
}

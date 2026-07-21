//
//  RenameTrackFileSheet.swift
//  TrackList
//
//  UI-форма для ручного ввода нового имени файла трека.
//  Отвечает только за поле ввода и не содержит логики сохранения или навигации.
//
//  Created by Pavel Fomin on 17.05.2026.
//

import SwiftUI

struct RenameTrackFileSheet: View {

    // MARK: - Input

    /// Связанное состояние имени файла.
    /// Источник истины находится в контейнере.
    @Binding var fileName: String

    /// Состояние фокуса поля ввода.
    /// Управляется контейнером, чтобы снимать focus до закрытия sheet.
    let isFileNameFocused: FocusState<Bool>.Binding

    // MARK: - UI

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "File Name"), text: $fileName)
                    .clearable($fileName)
                    .focused(isFileNameFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.none)
                    .keyboardType(.default)
                    .submitLabel(.done)
                    .onSubmit {
                        isFileNameFocused.wrappedValue = false
                    }
            }
        }
        .formStyle(.grouped)

        /// Автоматически устанавливаем фокус при появлении шита.
        .task {
            isFileNameFocused.wrappedValue = true
        }
    }
}

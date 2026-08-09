//
//  SaveTrackListSheet.swift
//  TrackList
//
//  Экран сохранения текущей очереди плеера в новый треклист.
//  Чистая UI-форма ввода имени.
//
//  ВАЖНО:
//  - конфигурирует единый навигационный тулбар через NavigationBarHost
//  - НЕ содержит бизнес-логики (сохранение, закрытие и т.п.)
//  - Используется ТОЛЬКО как визуальный слой
//  - Всё управление состоянием и действиями находится во ViewModel
//
//  Created by Pavel Fomin on 11.07.2025.
//

import SwiftUI

struct SaveTrackListSheet: View {

    // MARK: - Input

    /// Готовое presentation-состояние формы.
    let state: SaveTrackListState
    /// Typed-действия, передаваемые во ViewModel.
    let onAction: (SaveTrackListAction) -> Void

    /// Состояние фокуса поля ввода.
    /// Управляется sheet-компонентом, чтобы снимать focus до закрытия sheet.
    @FocusState private var isNameFocused: Bool

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Tracklist Name",
            rightButtonImage: "checkmark",
            isRightEnabled: .constant(state.canSubmit),
            onClose: {
                finishEditing()
                onAction(.cancel)
            },
            onRightTap: {
                finishEditing()
                onAction(.submit)
            }
        ) {
            form
        }
    }

    /// Содержимое формы сохранения очереди плеера.
    private var form: some View {
        Form {
            Section {
                TextField("Tracklist Name", text: nameBinding)
                    .clearable(nameBinding)
                    .focused($isNameFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .textContentType(.none)
                    .keyboardType(.default)
                    .submitLabel(.done)
                    .onSubmit {
                        finishEditing()
                    }
            }
        }
        .formStyle(.grouped)

        /// Автоматически устанавливаем фокус при появлении шита,
        /// чтобы сразу открыть клавиатуру без дополнительного тапа.
        .task {
            isNameFocused = true
        }
    }

    /// Снимает фокус с поля ввода перед закрытием или подтверждением.
    private func finishEditing() {
        isNameFocused = false
    }

    /// Связывает TextField с presentation-state через typed action ViewModel.
    private var nameBinding: Binding<String> {
        Binding(
            get: { state.name },
            set: { onAction(.nameChanged($0)) }
        )
    }
}

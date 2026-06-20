//
//  RenameTrackListSheet.swift
//  TrackList
//
//  UI-форма для ввода нового имени треклиста.
//
//  Роль компонента:
//  - отображает поле ввода имени
//  - управляет фокусом TextField
//  - конфигурирует единый навигационный тулбар через NavigationBarHost
//  - не содержит бизнес-логики
//
//  Архитектурные принципы:
//  - не знает о SheetManager
//  - не знает о командах сохранения
//  - не управляет закрытием sheet’а
//  - используется только внутри RenameTrackListContainer
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct RenameTrackListSheet: View {

    // MARK: - Input

    /// Связанное состояние имени треклиста.
    /// Источник истины находится в контейнере.
    @Binding var name: String

    /// Можно ли подтвердить переименование с текущим названием.
    let canSubmit: Bool
    /// Действие подтверждения переименования.
    let onSubmit: () -> Void
    /// Действие закрытия sheet без переименования.
    let onCancel: () -> Void

    /// Состояние фокуса поля ввода.
    /// Управляется sheet-компонентом, чтобы снимать focus до закрытия sheet.
    @FocusState private var isNameFocused: Bool

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            /// Заголовок шита
            title: "Переименовать треклист",

            /// Кнопка подтверждения (✓)
            rightButtonImage: "checkmark",

            /// Активна только при валидном имени
            isRightEnabled: .constant(canSubmit),

            /// Закрытие sheet’а без действий
            onClose: {
                finishEditing()
                onCancel()
            },

            /// Подтверждение переименования
            onRightTap: {
                finishEditing()
                onSubmit()
            }
        ) {
            form
        }
    }

    /// Содержимое формы переименования треклиста.
    private var form: some View {
        Form {
            Section {
                TextField("Новое название", text: $name)
                    .clearable($name)
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
}

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
//  - получает готовый state и отправляет typed actions
//
//  Created by Pavel Fomin on 09.11.2025.
//

import SwiftUI

struct RenameTrackListSheet: View {

    // MARK: - Input

    /// Готовое presentation-состояние формы.
    let state: RenameTrackListState
    /// Typed-действия, передаваемые во ViewModel.
    let onAction: (RenameTrackListAction) -> Void

    /// Состояние фокуса поля ввода.
    /// Управляется sheet-компонентом, чтобы снимать focus до закрытия sheet.
    @FocusState private var isNameFocused: Bool

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            /// Заголовок шита
            title: "Rename Tracklist",

            /// Кнопка подтверждения (✓)
            rightButtonImage: "checkmark",

            /// Активна только при валидном имени
            isRightEnabled: .constant(state.canSubmit),

            /// Закрытие sheet’а без действий
            onClose: {
                finishEditing()
                onAction(.cancel)
            },

            /// Подтверждение переименования
            onRightTap: {
                finishEditing()
                onAction(.submit)
            }
        ) {
            form
        }
    }

    /// Содержимое формы переименования треклиста.
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

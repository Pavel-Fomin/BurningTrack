//
//  RenameTrackListContainer.swift
//  TrackList
//
//  UI-контейнер экрана переименования треклиста.
//
//  Роль контейнера:
//  - владеет состоянием формы (name)
//  - выполняет команду переименования треклиста
//  - управляет закрытием sheet’а
//  - конфигурирует единый навигационный тулбар через NavigationBarHost
//
//  Архитектурные принципы:
//  - контейнер не содержит визуальной разметки формы
//  - контейнер не рисует TextField напрямую
//  - контейнер является аналогом UIViewController в UIKit
//  - RenameTrackListSheet — чистый UI-компонент без логики
//
//  Created by Pavel Fomin on 21.01.2026.
//

import SwiftUI
import Foundation

struct RenameTrackListContainer: View {

    /// Данные, переданные через SheetManager при открытии sheet’а.
    let data: RenameTrackListSheetData

    /// Локальное состояние формы — источник истины
    @State private var name: String

    /// Фокус поля имени для управления клавиатурой из контейнера.
    @FocusState private var isNameFocused: Bool

    init(data: RenameTrackListSheetData) {
        self.data = data
        self._name = State(initialValue: data.currentName)
    }

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            /// Заголовок шита
            title: "Переименовать треклист",

            /// Кнопка подтверждения (✓)
            rightButtonImage: "checkmark",

            /// Активна только при валидном имени
            isRightEnabled: .constant(
                TrackListManager.shared.validateName(name)
            ),

            /// Закрытие sheet’а без действий
            onClose: {
                closeSheet()
            },

            /// Подтверждение переименования
            onRightTap: {
                Task { await rename() }
            }
        ) {
            /// Чистый UI-слой формы
            RenameTrackListSheet(
                name: $name,
                isNameFocused: $isNameFocused
            )
        }
    }

    // MARK: - Actions

    /// Закрывает sheet после предварительного снятия фокуса с поля ввода.
    private func closeSheet() {
        isNameFocused = false
        SheetManager.shared.closeActive()
    }

    /// Асинхронная операция переименования треклиста
    private func rename() async {
        do {
            try await AppCommandExecutor.shared.renameTrackList(
                trackListId: data.trackListId,
                newName: name
            )
            closeSheet()
        } catch let appError as AppError {
            print("❌ Ошибка переименования треклиста: \(appError)")
            ToastManager.shared.handle(appError)
        } catch {
            print("❌ Ошибка переименования треклиста: \(error)")
            ToastManager.shared.handle(AppError.trackListSaveFailed)
        }
    }
}

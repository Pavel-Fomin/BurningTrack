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

import Foundation
import SwiftUI

struct RenameTrackListContainer: View {

    /// Данные, переданные через SheetManager при открытии sheet’а.
    /// Содержат идентификатор треклиста и текущее имя.
    let data: RenameTrackListSheetData

    /// Локальное состояние формы.
    /// Является единственным источником истины для вводимого имени.
    @State private var name: String

    /// Инициализация контейнера.
    /// Начальное значение формы берётся из текущего имени треклиста.
    init(data: RenameTrackListSheetData) {
        self.data = data
        self._name = State(initialValue: data.currentName)
    }

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            /// Заголовок шита
            title: "Переименовать треклист",

            /// Управление доступностью кнопки подтверждения.
            /// Кнопка активна только при валидном имени треклиста.
            isRightEnabled: .constant(
                TrackListManager.shared.validateName(name)
            ),

            /// Закрытие sheet’а без выполнения действий.
            onClose: {
                SheetManager.shared.closeActive()
            },

            /// Подтверждение переименования треклиста.
            /// Асинхронная команда выполняется через AppCommandExecutor.
            onConfirm: {
                Task { await rename() }
            }
        ) {
            /// Чистый UI-слой формы.
            /// Контейнер не знает о внутренней разметке RenameTrackListSheet.
            RenameTrackListSheet(name: $name)
        }
    }

    // MARK: - Actions

    /// Асинхронная операция переименования треклиста.
    /// При успешном выполнении закрывает текущий sheet.
    /// Ошибки логируются, централизованная UI-обработка может быть добавлена позже.
    private func rename() async {
        do {
            try await AppCommandExecutor.shared.renameTrackList(
                trackListId: data.trackListId,
                newName: name
            )
            SheetManager.shared.closeActive()
        } catch {
            print("❌ Ошибка переименования треклиста: \(error)")
        }
    }
}

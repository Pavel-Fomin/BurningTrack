//
//  SaveTrackListContainer.swift
//  TrackList
//
//  UI-контейнер экрана создания треклиста.
//
//  Роль контейнера:
//  - владеет состоянием формы (name)
//  - управляет бизнес-действием сохранения
//  - управляет закрытием sheet’а
//  - конфигурирует NavigationBarHost
//
//  ВАЖНО:
//  - НЕ содержит визуальной разметки формы
//  - НЕ рисует TextField напрямую
//  - НЕ используется повторно как UI-компонент
//  - является аналогом UIViewController в UIKit
//
//  Created by Pavel Fomin on 21.01.2026.
//

import Foundation
import SwiftUI

struct SaveTrackListContainer: View {

    // MARK: - State

    @State private var name = generateDefaultTrackListName() /// Название нового треклиста. Источником для формы. Передаётся через Binding

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Название треклиста",

            /// Управление доступностью кнопки подтверждения. Кнопка активна только при валидном имени.
            isRightEnabled: .constant(
                TrackListManager.shared.validateName(name)
            ),

            /// Закрытие sheet’а без выполнения действий
            onClose: {
                SheetManager.shared.closeActive()
            },

            /// Подтверждение создания треклиста. Асинхронная команда.
            onConfirm: {
                Task { await create() }
            }
        ) {
            /// Чистый UI-слой формы. Контейнер не знает о внутренней разметке sheet’а.
            SaveTrackListSheet(name: $name)
        }
    }

    // MARK: - Actions

    // Асинхронное создание треклиста. При успехе закрывает текущий sheet. Ошибки логируются, UI-обработка ошибок может быть добавлена позже централизованно.
    private func create() async {
        do {
            try await AppCommandExecutor.shared.createTrackList(name: name)
            SheetManager.shared.closeActive()
        } catch {
            print("❌ Ошибка сохранения треклиста: \(error)")
        }
    }
}

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

import SwiftUI
import Foundation

struct SaveTrackListContainer: View {

    // MARK: - State

    /// Название нового треклиста. Источник истины для формы.
    @State private var name = generateDefaultTrackListName()

    // MARK: - UI

    var body: some View {
        NavigationBarHost(
            title: "Название треклиста",

            /// Кнопка подтверждения (✓)
            rightButtonImage: "checkmark",

            /// Активна только при валидном имени
            isRightEnabled: .constant(
                TrackListManager.shared.validateName(name)
            ),

            /// Закрытие sheet’а без действий
            onClose: {
                SheetManager.shared.closeActive()
            },

            /// Подтверждение создания треклиста
            onRightTap: {
                Task { await create() }
            }
        ) {
            /// Чистый UI-слой формы
            SaveTrackListSheet(name: $name)
        }
    }

    // MARK: - Actions

    /// Асинхронное создание треклиста
    private func create() async {
        do {
            try await AppCommandExecutor.shared.createTrackList(name: name)
            SheetManager.shared.closeActive()
        } catch {
            print("❌ Ошибка сохранения треклиста: \(error)")
        }
    }
}

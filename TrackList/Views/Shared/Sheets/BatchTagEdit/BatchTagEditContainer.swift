//
//  BatchTagEditContainer.swift
//  TrackList
//
//  Контейнер sheet массового редактирования тегов.
//
//  Created by PavelFomin on 25.05.2026.
//

import SwiftUI

/// Контейнер sheet массового редактирования тегов.
///
/// Роль:
/// - владеет navigation/header через NavigationBarHost;
/// - закрывает sheet через onClose;
/// - не содержит логики сохранения тегов.
struct BatchTagEditContainer: View {
    /// Состояние flow массового редактирования тегов.
    @Binding var flow: BatchTagEditFlow

    /// Закрытие sheet.
    let onClose: () -> Void

    /// Сохранение изменений.
    let onSave: () async -> Void

    /// Выполняется ли сохранение изменений.
    @State private var isSaving = false

    var body: some View {
        NavigationBarHost(
            title: "Редактирование тегов",
            rightButtonImage: "checkmark",
            isRightEnabled: .constant(flow.canSave && !isSaving),
            onClose: onClose,
            onRightTap: {
                Task {
                    await save()
                }
            }
        ) {
            BatchTagEditSheet(flow: $flow)
        }
    }

    /// Запускает сохранение изменений.
    private func save() async {
        guard flow.canSave else { return }
        isSaving = true
        flow.phase = .saving
        await onSave()
        flow.phase = .editing
        isSaving = false
    }
}

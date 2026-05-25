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

    var body: some View {
        NavigationBarHost(
            title: "Редактирование тегов",
            rightButtonImage: nil,
            isRightEnabled: .constant(false),
            onClose: onClose
        ) {
            BatchTagEditSheet(flow: $flow)
        }
    }
}

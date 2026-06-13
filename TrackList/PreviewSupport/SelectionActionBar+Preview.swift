//
//  SelectionActionBar+Preview.swift
//  TrackList
//
//  Xcode Preview для панели действий режима выбора.
//
//  Created by Pavel Fomin on 13.06.2026.
//

#if DEBUG
import SwiftUI

/// Размещает панель выбора в нижней части экрана, как в рабочем интерфейсе.
private struct SelectionActionBarPreviewContainer: View {
    let subtitle: String
    let isPrimaryEnabled: Bool

    var body: some View {
        VStack {
            Spacer()
            SelectionActionBar(
                title: "Выбрано",
                subtitle: subtitle,
                primaryTitle: "Добавить",
                iconName: "music.note",
                isPrimaryEnabled: isPrimaryEnabled,
                onPrimaryTap: {}
            )
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Выбран один — iPhone") {
    SelectionActionBarPreviewContainer(
        subtitle: "1 трек",
        isPrimaryEnabled: true
    )
}

#Preview("Выбрано несколько — iPhone") {
    SelectionActionBarPreviewContainer(
        subtitle: "12 треков",
        isPrimaryEnabled: true
    )
}

#Preview("Действие недоступно — iPhone") {
    SelectionActionBarPreviewContainer(
        subtitle: "0 треков",
        isPrimaryEnabled: false
    )
}

#Preview("Выбрано несколько — iPad") {
    SelectionActionBarPreviewContainer(
        subtitle: "24 трека",
        isPrimaryEnabled: true
    )
}
#endif

//
//  TrackSelectableSectionsView.swift
//  TrackList
//
//  Базовый список треков с поддержкой мультиселекта.
//  Не содержит логики плеера, шитов и других зависимостей.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI

struct TrackSelectableSectionsView: View {

    // MARK: - Input

    /// Секции с готовым presentation-состоянием строк.
    let sections: [TrackSelectableSectionState]

    /// Передаёт действие выбора владельцу состояния sheet.
    let onToggleSelection: (LibraryTrack) -> Void
    /// Передаёт недоступную строку feature-local action маршруту без мутации выбора.
    let onUnavailableTap: (LibraryTrack) -> Void

    /// Запрашивает runtime snapshot через ViewModel фонотеки.
    let onRequestSnapshot: (UUID) -> Void

    // MARK: - UI

    var body: some View {
        ForEach(sections, id: \.id) { section in
            Section {
                ForEach(section.rows) { row in

                    TrackSelectableRowWrapper(
                        state: row,
                        onToggleSelection: {
                            onToggleSelection(row.track)
                        },
                        onUnavailableTap: {
                            onUnavailableTap(row.track)
                        },
                        onRequestSnapshot: onRequestSnapshot
                    )
                }
            } header: {

                // Заголовок секции (если есть)
                if section.showsHeader {
                    Text(LibraryPresentationText.trackSectionHeader(section.header))
                }
            }
        }
    }
}

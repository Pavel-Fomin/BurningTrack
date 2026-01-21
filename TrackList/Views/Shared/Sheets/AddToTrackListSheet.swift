//
//  AddToTrackListSheet.swift
//  TrackList
//
//  UI-форма выбора треклиста для добавления трека.
//
//  Роль компонента:
//  - отображает список треклистов
//  - позволяет выбрать треклист назначения
//  - визуально отмечает текущий активный треклист
//
//  Архитектурные принципы:
//  - не содержит бизнес-логики
//  - не выполняет команд добавления
//  - не управляет закрытием sheet’а
//  - подтверждение и отмена обрабатываются контейнером
//
//  Created by Pavel Fomin on 29.07.2025.
//

import SwiftUI
import Foundation

struct AddToTrackListSheet: View {
    
    // MARK: - Input
    
    let trackLists: [TrackListsManager.TrackListMeta]  /// Список доступных треклистов (read-only).
    let currentTrackListId: UUID?                      /// Текущий  треклист. Используется для бейджа «Текущий»
    
    @Binding var selectedTrackListId: UUID?            /// Выбранный треклист назначения.Источник истины находится в контейнере
    
    
    // MARK: - UI
    
    var body: some View {
        List(trackLists) { meta in
            Button {
                guard meta.id != currentTrackListId else { return }
                
                selectedTrackListId =
                (selectedTrackListId == meta.id) ? nil : meta.id
            } label: {
                HStack(spacing: 12) {
                    
                    Text(meta.name)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if meta.id == currentTrackListId {
                        // Бейдж "Текущий"
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .frame(width: 28, height: 28)
                    } else {
                        Image(
                            systemName:
                                selectedTrackListId == meta.id
                            ? "largecircle.fill.circle"
                            : "circle"
                        )
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color(.tertiarySystemBackground))
        }
    }
}

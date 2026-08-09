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
//  - отправляет typed actions во ViewModel
//
//  Created by Pavel Fomin on 29.07.2025.
//

import SwiftUI
import Foundation

struct AddToTrackListSheet: View {
    
    // MARK: - Input
    
    /// Готовое presentation-состояние экрана.
    let state: AddToTrackListState
    /// Typed-действия, передаваемые во ViewModel.
    let onAction: (AddToTrackListAction) -> Void
    
    
    // MARK: - UI
    
    var body: some View {
        NavigationBarHost(
            title: "Add to Tracklist",
            rightButtonImage: "checkmark",
            isRightEnabled: .constant(state.canSubmit),
            onClose: {
                onAction(.cancel)
            },
            onRightTap: {
                onAction(.submit)
            }
        ) {
            trackListContent
        }
    }

    /// Сохраняет визуальное отображение списка и состояния отсутствия треклистов.
    private var trackListContent: some View {
        List {
            if state.isLoading {
                ProgressView()
            } else if state.items.isEmpty {
                ContentUnavailableView(
                    "No Tracklists",
                    systemImage: "music.note.list"
                )
            } else {
                trackListRows
            }
        }
    }

    @ViewBuilder
    private var trackListRows: some View {
        ForEach(state.items) { item in
            Button {
                guard item.isAvailable else { return }

                onAction(.trackListSelected(item.id))
            } label: {
                HStack(spacing: 12) {
                    Text(item.title)
                        .lineLimit(1)

                    Spacer()

                    if !item.isAvailable {
                        // Бейдж "Текущий"
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.green)
                            .frame(width: 28, height: 28)
                            .accessibilityHidden(true)
                    } else {
                        Image(
                            systemName:
                                item.isSelected
                            ? "largecircle.fill.circle"
                            : "circle"
                        )
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color(.tertiarySystemBackground))
            .accessibilityValue(accessibilityValue(for: item))
        }
    }

    /// Возвращает VoiceOver-статус строки без изменения данных выбора.
    private func accessibilityValue(for item: AddToTrackListItemState) -> String {
        if !item.isAvailable {
            return String(localized: "Current Tracklist")
        }

        if item.isSelected {
            return String(localized: "Selected")
        }

        return ""
    }
}

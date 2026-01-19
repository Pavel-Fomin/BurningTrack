//
//  LibraryTracksToolbar.swift
//  TrackList
//
//  Тулбар экрана с треками в фонотеке.
//  Поддерживает режим мультиселекта.
//
//  Created by PavelFomin on 10.01.2026.
//

import SwiftUI

struct LibraryTracksToolbar: ViewModifier {

    let title: String
    let selectedCount: Int

    let onTapSelect: () -> Void
    let onTapCancel: () -> Void

    @Binding var isSelecting: Bool
    
    @State private var isAllSelected = false

    
    // MARK: - UI
    
    func body(content: Content) -> some View {
        content
            .screenToolbar(
                title: isSelecting ? "Выбрано" : title,
                subtitle: isSelecting ? "\(selectedCount)" : nil,
                isTitleSecondary: isSelecting,
                leading: { leadingContent }
            )
            .navigationBarBackButtonHidden(isSelecting)
            .toolbar {
                trailingToolbarContent
            }
    }

    // Leading toolbar content
    @ViewBuilder
    private var leadingContent: some View {
        if isSelecting {
            Button {
                isAllSelected.toggle()
                /// позже сюда подключится логика select/deselect
            } label: {
                Image(systemName: isAllSelected
                      ? "checkmark.circle.fill"
                      : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isAllSelected ? .green : .primary)
            }
            .accessibilityLabel(
                isAllSelected ? "Снять выделение" : "Выбрать все"
            )
        } else {
            EmptyView()
        }
    }

    // Trailing toolbar content
    @ToolbarContentBuilder
    private var trailingToolbarContent: some ToolbarContent {

        if isSelecting {

            // 1. Меню
            ToolbarItem(placement: .topBarTrailing) {
                Menu {

                    /// Добавить
                    Text("Добавить")

                    Divider()

                    Button {
                    /// В плеер
                    } label: {
                        Label("В плеер", systemImage: "waveform")
                    }

                    Button {
                    /// В треклист
                    } label: {
                        Label("В треклист", systemImage: "list.star")
                    }

                    Divider()

                    /// Изменить
                    Text("Изменить")
                        .foregroundStyle(.secondary)

                    Divider()

                    Button {
                    /// Переименовать
                    } label: {
                        Label("Переименовать", systemImage: "pencil")
                    }

                    Button {
                    /// Редактировать теги
                    } label: {
                        Label("Редактировать теги", systemImage: "tag")
                    }

                } label: {
                    Image(systemName: "ellipsis")
                }
            }

            /// 2. Закрыть
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onTapCancel) {
                    Image(systemName: "xmark")
                }
            }

        } else {
            
            /// Редактировать
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onTapSelect) {
                    Image(systemName: "pencil")
                }
            }
        }
    }
}

// MARK: - Modifier

extension View {

    func libraryTracksToolbar(
        title: String,
        isSelecting: Binding<Bool>,
        selectedCount: Int,
        onTapSelect: @escaping () -> Void,
        onTapCancel: @escaping () -> Void
    ) -> some View {
        self.modifier(
            LibraryTracksToolbar(
                title: title,
                selectedCount: selectedCount,
                onTapSelect: onTapSelect,
                onTapCancel: onTapCancel,
                isSelecting: isSelecting
            )
        )
    }
}

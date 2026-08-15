//
//  MoveToFolderSheet.swift
//  TrackList
//
//  Отображает готовое дерево папок и передаёт typed выбор feature-flow.
//
//  Created by Pavel Fomin on 07.12.2025.
//

import SwiftUI
import Foundation

struct MoveToFolderSheet: View {

    // MARK: - Входные данные

    /// Заголовок верхнего уровня готового screen state.
    let rootNavigationTitle: String
    /// Выбранная папка назначения.
    let selectedFolderID: UUID?
    /// Текущая папка трека нужна для отметки и исключается из доступных папок назначения.
    let currentFolderID: UUID?
    /// Lightweight snapshot исключает production-зависимости из leaf View и navigation context.
    let folderSnapshot: MoveToFolderFolderSnapshot
    /// Направляет изменение выбора в typed feature action.
    let onFolderSelectionChanged: (UUID?) -> Void

    // MARK: - Состояние

    /// Сохраняет путь внутри дерева при пересчётах родительского View.
    @StateObject private var nav: MoveToFolderNavigationContext

    init(
        rootNavigationTitle: String,
        folderSnapshot: MoveToFolderFolderSnapshot,
        selectedFolderID: UUID?,
        currentFolderID: UUID?,
        onFolderSelectionChanged: @escaping (UUID?) -> Void
    ) {
        self.rootNavigationTitle = rootNavigationTitle
        self.folderSnapshot = folderSnapshot
        self.selectedFolderID = selectedFolderID
        self.currentFolderID = currentFolderID
        self.onFolderSelectionChanged = onFolderSelectionChanged
        _nav = StateObject(
            wrappedValue: MoveToFolderNavigationContext(snapshot: folderSnapshot)
        )
    }

    // MARK: - Интерфейс

    var body: some View {
        List(nav.rows(currentFolderID: currentFolderID)) { row in
            HStack(spacing: 12) {

                Button {
                    nav.enter(row.id)
                } label: {
                    HStack(spacing: 10) {
                        Text(row.name)
                            .lineLimit(1)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityValue(
                    row.id == currentFolderID
                    ? MoveToFolderPresentationText.currentFolderAccessibilityValue
                    : ""
                )

                if row.id != currentFolderID {
                    Button {
                        onFolderSelectionChanged(
                            selectedFolderID == row.id ? nil : row.id
                        )
                    } label: {
                        Image(
                            systemName:
                                selectedFolderID == row.id
                                ? "largecircle.fill.circle"
                                : "circle"
                        )
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        MoveToFolderPresentationText.selectFolderAccessibilityLabel(
                            for: row.name
                        )
                    )
                    .accessibilityValue(
                        selectedFolderID == row.id ? String(localized: "Selected") : ""
                    )
                } else {
                    Spacer()
                        .frame(width: 28)
                }
            }
            .overlay(alignment: .trailing) {

                if row.id == currentFolderID {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                        .frame(width: 28, height: 28)
                }
            }
            .listRowBackground(Color(.tertiarySystemBackground))
        }
        .navigationTitle(
            MoveToFolderPresentationText.navigationTitle(
                rootTitle: rootNavigationTitle,
                currentFolderName: nav.currentFolderName
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if nav.canGoBack {
                    Button {
                        nav.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
    }
}

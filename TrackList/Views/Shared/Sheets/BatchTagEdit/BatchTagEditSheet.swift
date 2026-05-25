//
//  BatchTagEditSheet.swift
//  TrackList
//
//  Sheet массового редактирования тегов.
//
//  Created by PavelFomin on 25.05.2026.
//

import Foundation
import SwiftUI
import UIKit

struct BatchTagEditSheet: View {
    /// Состояние flow массового редактирования тегов.
    @Binding var flow: BatchTagEditFlow

    var body: some View {
        content
    }

    /// Основное содержимое формы.
    @ViewBuilder
    private var content: some View {
        switch flow.phase {
        case .loadingMetadata:
            loadingView

        case .editing:
            editingContent
        }
    }

    /// Состояние загрузки метаданных.
    private var loadingView: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    ProgressView()

                    Text("Читаю теги выбранных треков…")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    /// Содержимое режима редактирования.
    private var editingContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                BatchTagArtworkEditSection(
                    artwork: $flow.artwork,
                    onMenuAction: handleArtworkMenuAction
                )

                ForEach(flow.fields) { fieldState in
                    fieldRow(for: fieldState.field)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    /// Строка редактирования одного поля.
    private func fieldRow(for field: EditableTrackField) -> some View {
        EditableFieldRow(
            title: field.title,
            isMultiline: field == .comment,
            keyboardType: keyboardType(for: field),
            value: binding(for: field).value
        )
    }

    /// Binding для конкретного поля внутри массива states.
    private func binding(for field: EditableTrackField) -> Binding<BatchTagFieldEditState> {
        Binding(
            get: {
                guard let index = flow.fields.firstIndex(where: { $0.field == field }) else {
                    return BatchTagFieldEditState(
                        field: field,
                        action: .keep,
                        value: "",
                        summary: .empty
                    )
                }

                return flow.fields[index]
            },
            set: { newValue in
                guard let index = flow.fields.firstIndex(where: { $0.field == field }) else { return }
                flow.fields[index] = newValue
            }
        )
    }

    /// Тип клавиатуры для конкретного поля.
    private func keyboardType(for field: EditableTrackField) -> UIKeyboardType {
        switch field {
        case .year:
            return .numberPad
        default:
            return .default
        }
    }

    /// Обрабатывает выбор действия в меню карточки обложки.
    private func handleArtworkMenuAction(
        _ action: BatchTagArtworkMenuAction,
        target: BatchTagArtworkActionTarget
    ) {
        flow.artwork.selectedTarget = target
        switch action {
        case .remove:
            flow.artwork.action = .remove
        case .replace:
            flow.artwork.action = .replace
        case .compress:
            flow.artwork.action = .keep
        }
    }
}

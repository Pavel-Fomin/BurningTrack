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

        case .saving:
            savingView
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

    /// Состояние сохранения тегов.
    private var savingView: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    ProgressView()

                    Text("Обновляю теги выбранных треков…")
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

                ForEach(displayedFields) { fieldState in
                    fieldRow(for: fieldState)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
    }

    /// Строка редактирования одного поля.
    private func fieldRow(for fieldState: BatchTagFieldEditState) -> some View {
        let fieldValue = valueBinding(for: fieldState)
        return EditableFieldRow(
            title: fieldState.field.title,
            isMultiline: fieldState.field == .comment,
            keyboardType: keyboardType(for: fieldState.field),
            placeholder: placeholder(for: fieldState),
            value: fieldValue,
            showsClearButton: fieldState.summary == .mixed && fieldState.action == .keep,
            onForceClear: {
                updateFieldValue("", for: fieldState.field)
            }
        )
    }

    /// Поля, которые нужно показать с учётом выбранной цели обложек.
    private var displayedFields: [BatchTagFieldEditState] {
        guard case .track(let trackId) = flow.artwork.selectedTarget,
              let track = flow.tracks.first(where: { $0.trackId == trackId }) else {
            return flow.fields
        }

        return EditableTrackField.allCases.map { field in
            if let override = flow.trackFieldOverrides[trackId]?.fields[field] {
                return override
            }

            let value = track.values[field] ?? ""
            return BatchTagFieldEditState(
                field: field,
                action: .keep,
                value: value,
                summary: value.isEmpty ? .empty : .same(value)
            )
        }
    }

    /// Binding значения поля с учётом выбранной цели.
    private func valueBinding(for fieldState: BatchTagFieldEditState) -> Binding<String> {
        Binding(
            get: {
                currentValue(for: fieldState.field)
            },
            set: { newValue in
                updateFieldValue(newValue, for: fieldState.field)
            }
        )
    }

    /// Текущее значение поля с учётом выбранной цели.
    private func currentValue(for field: EditableTrackField) -> String {
        if case .track(let trackId) = flow.artwork.selectedTarget {
            if let override = flow.trackFieldOverrides[trackId]?.fields[field] {
                return override.value
            }

            return flow.tracks.first(where: { $0.trackId == trackId })?.values[field] ?? ""
        }

        return flow.fields.first(where: { $0.field == field })?.value ?? ""
    }

    /// Обновляет значение поля и фиксирует намерение пользователя.
    private func updateFieldValue(_ value: String, for field: EditableTrackField) {
        if case .track(let trackId) = flow.artwork.selectedTarget {
            updateTrackFieldValue(value, for: field, trackId: trackId)
        } else {
            updateGroupFieldValue(value, for: field)
        }
    }

    /// Обновляет group-level значение поля.
    private func updateGroupFieldValue(_ value: String, for field: EditableTrackField) {
        guard let index = flow.fields.firstIndex(where: { $0.field == field }) else { return }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .same(let originalValue) = flow.fields[index].summary {
            let trimmedOriginalValue = originalValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedValue == trimmedOriginalValue {
                flow.fields[index].value = originalValue
                flow.fields[index].action = .keep
                return
            }
        }
        flow.fields[index].value = value
        flow.fields[index].action = action(for: value)
    }

    /// Обновляет значение поля для конкретного трека.
    private func updateTrackFieldValue(_ value: String, for field: EditableTrackField, trackId: UUID) {
        guard let track = flow.tracks.first(where: { $0.trackId == trackId }) else { return }

        let originalValue = track.values[field] ?? ""
        let trimmedNewValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOriginalValue = originalValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedNewValue == trimmedOriginalValue {
            removeTrackFieldOverride(field, trackId: trackId)
            return
        }

        var override = flow.trackFieldOverrides[trackId] ?? BatchTagTrackFieldOverride(
            trackId: trackId,
            fields: [:]
        )

        override.fields[field] = BatchTagFieldEditState(
            field: field,
            action: action(for: value),
            value: value,
            summary: value.isEmpty ? .empty : .same(value)
        )
        flow.trackFieldOverrides[trackId] = override
    }

    /// Удаляет per-track override, если значение вернули к исходному.
    private func removeTrackFieldOverride(_ field: EditableTrackField, trackId: UUID) {
        guard var override = flow.trackFieldOverrides[trackId] else { return }

        override.fields.removeValue(forKey: field)

        if override.fields.isEmpty {
            flow.trackFieldOverrides.removeValue(forKey: trackId)
        } else {
            flow.trackFieldOverrides[trackId] = override
        }
    }

    /// Intent действия по значению поля.
    private func action(for value: String) -> BatchTagFieldEditAction {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .clear : .set
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

    /// Placeholder для batch-состояния поля.
    private func placeholder(for fieldState: BatchTagFieldEditState) -> String {
        guard fieldState.action == .keep else { return "" }

        switch fieldState.summary {
        case .mixed:
            return "Смешанно"
        case .same, .empty:
            return ""
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
            flow.artwork.setAction(.remove, for: target)
        case .replace:
            flow.artwork.action = .replace
        case .compress:
            flow.artwork.action = .keep
        }
    }
}

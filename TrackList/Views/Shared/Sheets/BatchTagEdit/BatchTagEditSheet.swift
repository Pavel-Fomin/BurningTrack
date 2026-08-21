//
//  BatchTagEditSheet.swift
//  TrackList
//
//  Отображает готовое presentation-состояние массового редактирования тегов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI
import UIKit

/// Leaf sheet без mutable draft, manager-ов и domain-сервисов.
struct BatchTagEditSheet: View {
    /// Готовое состояние UI текущего feature-сеанса.
    let state: BatchTagEditScreenState
    /// Единственный typed-канал пользовательских намерений.
    let send: (BatchTagEditAction) -> Void
    /// Локальная цель нужна исключительно для открытия системного PhotosPicker.
    @State private var replacementTarget: BatchTagArtworkActionTarget?

    var body: some View {
        content
    }

    /// Отображает stage, подготовленный ViewModel.
    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .loadingMetadata:
            loadingView
        case .editing:
            editingContent
        case .saving:
            savingView
        }
    }

    /// Показывает загрузку metadata выбранных треков.
    private var loadingView: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(BatchTagEditPresentationText.loadingSelectedTracksTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    /// Показывает ожидание подтверждённой команды сохранения.
    private var savingView: some View {
        Form {
            Section {
                VStack(spacing: 12) {
                    ProgressView()
                    Text(BatchTagEditPresentationText.savingSelectedTracksTitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            }
        }
    }

    /// Собирает форму из presentation state и actions без прямой мутации flow.
    private var editingContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let saveSummary = state.saveSummary {
                    saveSummaryView(saveSummary)
                }

                BatchTagArtworkEditSection(
                    state: state.artwork,
                    send: send,
                    onReplaceRequested: { target in
                        send(.artworkReplaceTapped(target: target))
                        replacementTarget = target
                    }
                )

                ForEach(state.displayedFields) { fieldState in
                    fieldRow(for: fieldState)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .batchTagArtworkReplacementPicker(target: $replacementTarget) { target, data in
            send(.artworkReplacementSelected(target: target, data: data))
        }
    }

    /// Показывает готовый Presenter-ом partial result без интерпретации MutationFailure внутри View.
    private func saveSummaryView(
        _ summary: BatchTagEditSaveSummaryScreenState
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                String.localizedStringWithFormat(
                    String(localized: "batchMutation.savedCount"),
                    summary.confirmedCount
                )
            )
            .font(.subheadline.weight(.semibold))

            Text(
                String.localizedStringWithFormat(
                    String(localized: "batchMutation.requiresAttentionCount"),
                    summary.failures.count
                )
            )
            .font(.subheadline.weight(.semibold))

            ForEach(summary.failures) { failure in
                VStack(alignment: .leading, spacing: 2) {
                    Text(failure.trackName)
                        .font(.body)
                    Text(failure.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Строка поля передаёт новое значение в ViewModel как action.
    private func fieldRow(for state: BatchTagEditFieldScreenState) -> some View {
        EditableFieldRow(
            title: TagEditorPresentationText.fieldTitle(for: state.field),
            isMultiline: state.field == .comment,
            keyboardType: keyboardType(for: state.field),
            placeholder: state.placeholder,
            emphasizesPlaceholder: state.emphasizesPlaceholder,
            value: Binding(
                get: { state.value },
                set: { send(.fieldValueChanged(field: state.field, value: $0)) }
            ),
            showsClearButton: state.showsClearButton,
            onForceClear: {
                send(.fieldValueChanged(field: state.field, value: ""))
            }
        )
    }

    /// Сохраняет существующую раскладку клавиатуры для редактируемых полей.
    private func keyboardType(for field: EditableTrackField) -> UIKeyboardType {
        field == .year ? .numberPad : .default
    }
}

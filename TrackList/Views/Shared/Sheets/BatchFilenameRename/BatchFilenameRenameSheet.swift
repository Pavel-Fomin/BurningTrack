//
//  BatchFilenameRenameSheet.swift
//  TrackList
//
//  Leaf UI-форма подготовки массового переименования файлов.
//
//  Created by Pavel Fomin on 09.08.2026.
//

import SwiftUI

/// Отображает только готовое state и передаёт typed-действия без domain-вычислений.
struct BatchFilenameRenameSheet: View {
    /// Immutable presentation-состояние текущего feature-сеанса.
    let state: BatchFilenameRenameScreenState
    /// Единственный канал пользовательских намерений в ViewModel.
    let send: (BatchFilenameRenameAction) -> Void

    var body: some View {
        VStack(spacing: 0) {
            strategyPickerRow
                .disabled(!state.canSelectStrategy)
                .opacity(state.canSelectStrategy ? 1 : 0.5)

            if let progress = state.applyingProgress {
                progressView(
                    title: FileRenamePresentationText.renamingFilesTitle,
                    progress: progress
                )
            } else if let progress = state.preparationProgress {
                progressView(
                    title: FileRenamePresentationText.readingTagsTitle,
                    progress: progress
                )
            }

            listContent
                .opacity(state.isLoadingMetadata ? 0.55 : 1)

            renameFooter
        }
    }

    /// Отображает progress, уже подготовленный ViewModel.
    private func progressView(
        title: String,
        progress: BatchFilenameRenameProgress
    ) -> some View {
        BatchOperationProgressView(
            title: title,
            processedCount: progress.processedCount,
            totalCount: progress.totalCount
        )
    }

    /// Отображает строки state без построения domain rows внутри SwiftUI.
    @ViewBuilder
    private var listContent: some View {
        if state.rows.isEmpty {
            ContentUnavailableView(
                FileRenamePresentationText.noFilesTitle,
                systemImage: "music.note.list",
                description: Text(FileRenamePresentationText.noFilesDescription)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(state.rows) { row in
                BatchFilenameRenameRow(
                    state: row,
                    isRemovalEnabled: state.canRemoveTracks,
                    onRemove: {
                        send(.removeTrack(row.trackId))
                    }
                )
                .listRowBackground(Color(.tertiarySystemBackground))
            }
        }
    }

    /// Сохраняет существующее расположение кнопки Rename и меняет только источник доступности.
    private var renameFooter: some View {
        VStack(spacing: 0) {
            Button {
                send(.renameTapped)
            } label: {
                Text(String(localized: "Rename"))
                    .frame(maxWidth: .infinity)
            }
            .primaryButtonStyle()
            .disabled(!state.canApplyRename)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    /// Выбор стратегии читает только готовые title и идентичность из state.
    private var strategyPickerRow: some View {
        HStack(spacing: 12) {
            Text(FileRenamePresentationText.howToRenameTitle)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 12)

            Menu {
                strategyButton(.artistTitle)
                strategyButton(.titleArtist)
            } label: {
                HStack(spacing: 6) {
                    Text(state.selectedStrategyTitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .layoutPriority(2)

                    Image(systemName: "chevron.up.chevron.down")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color(.tertiarySystemBackground))
        .clipShape(Capsule())
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    /// Создаёт один пункт Menu без business-логики и выбора статуса в View.
    @ViewBuilder
    private func strategyButton(_ strategy: FilenameRenameStrategy) -> some View {
        Button {
            send(.strategySelected(strategy))
        } label: {
            let title = FileRenamePresentationText.strategyTitle(for: strategy)
            if state.selectedStrategy == strategy {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}

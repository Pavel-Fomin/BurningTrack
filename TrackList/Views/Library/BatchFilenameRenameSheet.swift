//
//  BatchFilenameRenameSheet.swift
//  TrackList
//
//  UI-форма подготовки массового переименования файлов.
//
//  Created by Pavel Fomin on 22.05.2026.
//

import SwiftUI

/// UI-форма подготовки массового переименования файлов.
///
/// Компонент только отображает список файлов и отдаёт действия наружу.
/// Реальное состояние и команды находятся во ViewModel.
struct BatchFilenameRenameSheet: View {

    // MARK: - Input

    let flow: BatchFilenameRenameFlow
    let canApplyRename: Bool
    let onSelectStrategy: (FilenameRenameStrategy) -> Void
    let onRemoveTrack: (UUID) -> Void
    let onRename: () -> Void

    // MARK: - UI

    var body: some View {
        VStack(spacing: 0) {
            strategyPickerRow
                .disabled(isLoadingMetadata || flow.isBusy)
                .opacity(isLoadingMetadata || flow.isBusy ? 0.5 : 1)

            if flow.isApplyingRename {
                applyingProgressView
            } else if flow.isPreparingRename {
                preparingProgressView
            }

            listContent
                .disabled(isLoadingMetadata || flow.isBusy)
                .opacity(isLoadingMetadata ? 0.55 : 1)

            renameFooter
        }
    }

    private var isLoadingMetadata: Bool {
        flow.phase == .loadingMetadata
    }

    private var preparingProgressView: some View {
        BatchOperationProgressView(
            title: "Читаю теги…",
            processedCount: flow.preparedRenameCount,
            totalCount: flow.totalPrepareCount
        )
    }

    private var applyingProgressView: some View {
        BatchOperationProgressView(
            title: "Переименовываю файлы…",
            processedCount: flow.processedRenameCount,
            totalCount: flow.totalRenameCount
        )
    }

    @ViewBuilder
    private var listContent: some View {
        if rows.isEmpty {
            ContentUnavailableView(
                "Нет файлов",
                systemImage: "music.note.list",
                description: Text("Все треки исключены из операции.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List(rows) { row in
                BatchFilenameRenameRow(
                    fileName: row.fileName,
                    statusDescription: row.statusDescription,
                    statusStyle: row.statusStyle,
                    onRemove: {
                        onRemoveTrack(row.trackId)
                    }
                )
                .listRowBackground(Color(.tertiarySystemBackground))
            }
        }
    }

    // MARK: - Footer

    private var renameFooter: some View {
        VStack(spacing: 0) {
            Button {
                onRename()
            } label: {
                Text("Переименовать")
                    .frame(maxWidth: .infinity)
            }
            .primaryButtonStyle()
            .disabled(!canApplyRename || flow.isBusy)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Strategy

    private var strategyPickerRow: some View {
        HStack(spacing: 12) {
            Text("Как переименовать")
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 12)

            Menu {
                Button {
                    onSelectStrategy(.artistTitle)
                } label: {
                    if flow.strategy == .artistTitle {
                        Label("Артист - Название", systemImage: "checkmark")
                    } else {
                        Text("Артист - Название")
                    }
                }

                Button {
                    onSelectStrategy(.titleArtist)
                } label: {
                    if flow.strategy == .titleArtist {
                        Label("Название - Артист", systemImage: "checkmark")
                    } else {
                        Text("Название - Артист")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedStrategyTitle)
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

    private var selectedStrategyTitle: String {
        switch flow.strategy {
        case .artistTitle:
            return "Артист - Название"
        case .titleArtist:
            return "Название - Артист"
        case nil:
            return "Выберите"
        }
    }

    // MARK: - Display

    private var rows: [BatchFilenameRenameDisplayRow] {
        if flow.items.isEmpty {
            return flow.tracks.map { track in
                BatchFilenameRenameDisplayRow(
                    trackId: track.trackId,
                    fileName: track.currentFileName,
                    statusDescription: nil,
                    statusStyle: .neutral
                )
            }
        }

        return flow.items.map { item in
            BatchFilenameRenameDisplayRow(
                trackId: item.trackId,
                fileName: item.displayedFileName,
                statusDescription: item.statusDescription,
                statusStyle: statusStyle(
                    isError: item.isErrorStatus,
                    isSuccess: item.isSuccessStatus
                )
            )
        }
    }

    private func statusStyle(
        isError: Bool,
        isSuccess: Bool
    ) -> BatchFilenameRenameRowStatusStyle {
        if isSuccess {
            return .success
        }

        if isError {
            return .error
        }

        return .neutral
    }
}

/// Строка отображения в sheet массового переименования.
private struct BatchFilenameRenameDisplayRow: Identifiable {
    let trackId: UUID
    let fileName: String
    let statusDescription: String?
    let statusStyle: BatchFilenameRenameRowStatusStyle

    var id: UUID { trackId }
}

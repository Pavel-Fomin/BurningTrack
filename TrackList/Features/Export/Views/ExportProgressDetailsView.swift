//
//  ExportProgressDetailsView.swift
//  TrackList
//
//  Подробное представление результата экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import SwiftUI

/// Показывает подробности операции без собственного состояния прогресса.
struct ExportProgressDetailsView: View {

    // MARK: - Dependencies

    /// Глобальная ViewModel передаётся через существующий environment приложения.
    @EnvironmentObject private var exportProgressViewModel: ExportProgressViewModel

    // MARK: - Presentation

    /// Безопасно форматирует количество байтов для короткого пользовательского текста.
    private func byteCountText(_ value: Int64) -> String {
        ByteCountFormatter.string(
            fromByteCount: max(value, 0),
            countStyle: .file
        )
    }

    /// Показывает название папки, выбранной пользователем до создания подпапки треклиста.
    private func rootDestinationName(for destination: ExportDestination) -> String {
        let parentURL = destination.folderURL.deletingLastPathComponent()
        let name = parentURL.lastPathComponent
        return name.isEmpty ? destination.displayName : name
    }

    // MARK: - UI

    var body: some View {
        Group {
            if let progress = exportProgressViewModel.progress {
                progressContent(progress)
            } else {
                ContentUnavailableView(
                    ExportPresentationText.noExportDataTitle,
                    systemImage: "arrow.up.doc",
                    description: Text(ExportPresentationText.noExportDataDescription)
                )
            }
        }
        .navigationTitle(ExportPresentationText.detailsNavigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Close")) {
                    if exportProgressViewModel.isExportActive {
                        exportProgressViewModel.dismissDetails()
                    } else {
                        exportProgressViewModel.dismissCompletedExport()
                    }
                }
            }
        }
        .onDisappear {
            exportProgressViewModel.detailsDidDisappear()
        }
    }

    /// Собирает содержимое карточки из единого снимка прогресса.
    @ViewBuilder
    private func progressContent(_ progress: ExportProgress) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(ExportPresentationText.statusTitle(for: progress.state))
                        .font(.title3.weight(.semibold))

                    LabeledContent(
                        ExportPresentationText.folderTitle,
                        value: progress.destination.displayName
                    )
                    LabeledContent(
                        ExportPresentationText.destinationTitle,
                        value: rootDestinationName(for: progress.destination)
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(ExportPresentationText.filesTitle)
                        .font(.headline)

                    Text(
                        ExportPresentationText.fileProgress(
                            completedCount: progress.completedFiles,
                            totalCount: progress.totalFiles
                        )
                    )
                        .font(.title2.monospacedDigit())

                    ProgressView(value: progressFraction(for: progress))
                        .tint(.accentColor)

                    Text(
                        ExportPresentationText.byteProgress(
                            copiedBytes: byteCountText(progress.copiedBytes),
                            totalBytes: byteCountText(progress.totalBytes)
                        )
                    )
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                if let currentFileName = progress.currentFileName {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ExportPresentationText.currentFileTitle)
                            .font(.headline)
                        Text(currentFileName)
                            .font(.body)
                            .lineLimit(3)
                    }
                }

                if !progress.failedFiles.isEmpty {
                    Label(
                        ExportPresentationText.failureCount(
                            progress.failedFiles.count
                        ),
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.orange)
                }

                if exportProgressViewModel.canCancel {
                    // Делегируем отмену глобальной ViewModel, чтобы сервис
                    // остановил FileHandle и удалил частичный файл.
                    Button(role: .destructive) {
                        _ = exportProgressViewModel.cancelExport()
                    } label: {
                        Text(ExportPresentationText.cancelExportTitle)
                            .frame(maxWidth: .infinity)
                    }
                    // Primary-стиль сохраняет заливку кнопки, а destructive-роль
                    // задаёт системный цвет отмены.
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// Вычисляет долю работы по байтам, а для пустых файлов по числу файлов.
    private func progressFraction(for progress: ExportProgress) -> Double {
        let completed: Int64
        let total: Int64

        if progress.totalBytes > 0 {
            completed = progress.copiedBytes
            total = progress.totalBytes
        } else {
            completed = Int64(progress.completedFiles)
            total = Int64(progress.totalFiles)
        }

        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }
}

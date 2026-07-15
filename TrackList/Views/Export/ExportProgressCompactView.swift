//
//  ExportProgressCompactView.swift
//  TrackList
//
//  Компактная глобальная панель текущего экспорта.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import SwiftUI

/// Показывает краткий прогресс экспорта над нижними панелями приложения.
struct ExportProgressCompactView: View {

    /// Одна форма используется для стекла, обрезки и hit-test зоны панели.
    private let panelShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    /// Фиксирует высоту верхней строки для активного и завершённого состояний.
    private let topRowHeight: CGFloat = 40

    /// Фиксирует область системной иконки, чтобы разные символы не меняли высоту строки.
    private let statusIconSize: CGFloat = 24

    /// Размер интерактивной области кнопки закрытия.
    private let dismissButtonSize: CGFloat = 36

    // MARK: - Input

    /// Снимок состояния, полученный напрямую от ExportProgressViewModel.
    let progress: ExportProgress

    /// Открывает подробный результат операции.
    let onTap: () -> Void

    /// Удаляет завершённый или отменённый результат из глобального состояния.
    let onDismiss: () -> Void

    // MARK: - Presentation

    /// Пульсация нужна только во время подготовки и фактического копирования.
    private var isExportActive: Bool {
        switch progress.state {
        case .preparing, .copying:
            return true
        case .idle, .completed, .completedWithErrors, .cancelled, .failed:
            return false
        }
    }

    /// Успешное завершение получает отдельный текст и кнопку закрытия.
    private var isCompleted: Bool {
        progress.state == .completed
    }

    /// Отменённая операция получает отдельное состояние до ручного закрытия.
    private var isCancelled: Bool {
        progress.state == .cancelled
    }

    /// Только завершённый или отменённый результат можно закрыть вручную.
    private var isDismissibleResult: Bool {
        isCompleted || isCancelled
    }

    /// Формирует короткий итоговый текст успешного копирования.
    private var completedTitle: String {
        "Копирование завершено"
    }

    /// Формирует короткий итоговый текст отменённого копирования.
    private var cancelledTitle: String {
        "Копирование отменено"
    }

    /// Выбирает системную иконку для текущего состояния операции.
    private var statusIconName: String {
        if isCompleted {
            return "checkmark.circle.fill"
        }

        if isCancelled {
            return "xmark.circle.fill"
        }

        return "document.on.document.fill"
    }

    /// Выбирает цвет итоговой иконки, не меняя оформление активного состояния.
    private var statusIconColor: Color {
        if isCompleted {
            return .green
        }

        if isCancelled {
            return .orange
        }

        return .accentColor
    }

    /// Возвращает текст компактной панели для терминального результата.
    private var resultTitle: String {
        isCancelled ? cancelledTitle : completedTitle
    }

    /// Выбирает цвет текста для успешного или отменённого результата.
    private var resultTitleColor: Color {
        isCompleted ? .green : .orange
    }

    /// Показывает долю записанных байтов, а для пустых файлов использует счётчик файлов.
    private var progressFraction: Double {
        if progress.totalBytes > 0 {
            return fraction(
                completed: progress.copiedBytes,
                total: progress.totalBytes
            )
        }

        return fraction(
            completed: Int64(progress.completedFiles),
            total: Int64(progress.totalFiles)
        )
    }

    /// Возвращает значение прогресса в безопасном диапазоне от нуля до единицы.
    private func fraction(completed: Int64, total: Int64) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    // MARK: - UI

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Основное содержимое остаётся отдельной кнопкой и открывает детали.
            // Кнопка закрытия размещается рядом, поэтому вложенных Button нет.
            Button(action: onTap) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: statusIconName)
                            .symbolEffect(
                                .pulse,
                                options: .repeating,
                                isActive: isExportActive
                            )
                            .foregroundStyle(statusIconColor)
                            .frame(width: statusIconSize, height: statusIconSize)

                        if isDismissibleResult {
                            Text(resultTitle)
                                .font(.subheadline)
                                .foregroundStyle(resultTitleColor)
                                .lineLimit(1)
                        } else {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Копирование")
                                    .font(.subheadline)
                                    .lineLimit(1)

                                Text(
                                    "Из «\(progress.sourceName)» "
                                        + "в «\(progress.rootDestinationName)»"
                                )
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }

                        Spacer(minLength: 8)

                        if !isCompleted {
                            Text("\(progress.completedFiles)/\(progress.totalFiles)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    // Резервируем место под крестик только в строке текста.
                    // ProgressView сохраняет полную ширину панели во всех состояниях.
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: topRowHeight, alignment: .center)
                    .padding(.trailing, isDismissibleResult ? 30 : 0)

                    ProgressView(value: progressFraction)
                        .tint(.accentColor)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isDismissibleResult {
                // В активной операции кнопка отсутствует: экспорт нельзя скрыть
                // до его завершения и случайно прервать отображение прогресса.
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: statusIconSize, height: statusIconSize)
                        .frame(
                            width: dismissButtonSize,
                            height: topRowHeight,
                            alignment: .trailing
                        )
                }
                .buttonStyle(.plain)
                // Область кнопки равна высоте верхней строки, поэтому крестик
                // центрируется рядом с иконкой и текстом без влияния на ProgressView.
                .accessibilityLabel("Закрыть результат копирования")
                .zIndex(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: panelShape)
        .clipShape(panelShape)
        .contentShape(panelShape)
        .modifier(
            ExportCompletionSwipeDismissModifier(
                isEnabled: isCompleted,
                onDismiss: onDismiss
            )
        )
        // Повторяем горизонтальные отступы мини-плеера: 16 у стекла и 8 у общего хоста.
        .padding(.horizontal, 16)
        .accessibilityLabel(
            isDismissibleResult ? resultTitle : "Прогресс экспорта"
        )
        .accessibilityValue(
            isDismissibleResult
                ? resultTitle
                : "\(progress.completedFiles) из \(progress.totalFiles), Копирование"
        )
    }
}

/// Добавляет жест закрытия только для успешно завершённого экспорта.
private struct ExportCompletionSwipeDismissModifier: ViewModifier {

    /// Разрешает жест только после успешного завершения копирования.
    let isEnabled: Bool

    /// Удаляет завершённый результат из глобального состояния.
    let onDismiss: () -> Void

    /// Добавляет жест горизонтального смахивания с безопасным порогом.
    func body(content: Content) -> some View {
        if isEnabled {
            content.highPriorityGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let horizontalDistance = abs(value.translation.width)
                        let verticalDistance = abs(value.translation.height)

                        guard horizontalDistance >= 80,
                              horizontalDistance > verticalDistance else {
                            return
                        }

                        onDismiss()
                    }
            )
        } else {
            content
        }
    }
}

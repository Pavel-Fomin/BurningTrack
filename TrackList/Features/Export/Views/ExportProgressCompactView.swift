//
//  ExportProgressCompactView.swift
//  TrackList
//
//  Компактная глобальная панель текущего экспорта.
//
//  Created by Pavel Fomin on 15.07.2026.
//

import SwiftUI

/// Показывает краткий прогресс экспорта над нижними панелями приложения.
struct ExportProgressCompactView: View {

    /// Одна форма используется для стекла, обрезки и hit-test зоны панели.
    private let panelShape = RoundedRectangle(cornerRadius: 24, style: .continuous)

    /// Фиксирует высоту верхней строки для активного и завершённого состояний.
    private let topRowHeight: CGFloat = 40

    /// Фиксирует размер иконки закрытия, чтобы она не меняла высоту строки.
    private let dismissIconSize: CGFloat = 24

    /// Размер интерактивной области кнопки закрытия.
    private let dismissButtonSize: CGFloat = 36

    // MARK: - Input

    /// Снимок состояния, полученный напрямую от ExportProgressViewModel.
    let progress: ExportProgress

    /// Открывает подробный результат операции.
    let onTap: () -> Void

    /// Удаляет терминальный результат из глобального состояния.
    let onDismiss: () -> Void

    // MARK: - Presentation

    /// Успешное завершение получает отдельный текст и кнопку закрытия.
    private var isCompleted: Bool {
        progress.state == .completed
    }

    /// Любой терминальный результат можно закрыть вручную.
    private var isDismissibleResult: Bool {
        switch progress.state {
        case .completed, .completedWithErrors, .cancelled, .failed:
            return true
        case .idle, .preparing, .copying:
            return false
        }
    }

    /// Формирует короткий итоговый текст успешного копирования.
    private var completedTitle: String {
        "Копирование завершено"
    }

    /// Формирует короткий итоговый текст отменённого копирования.
    private var cancelledTitle: String {
        "Копирование отменено"
    }

    /// Формирует короткий итоговый текст частично завершённого копирования.
    private var completedWithErrorsTitle: String {
        "Копирование завершено с ошибками"
    }

    /// Формирует короткий итоговый текст копирования с инфраструктурной ошибкой.
    private var failedTitle: String {
        "Копирование завершилось с ошибкой"
    }

    /// Возвращает текст компактной панели для терминального результата.
    private var resultTitle: String {
        switch progress.state {
        case .completed:
            return completedTitle
        case .completedWithErrors:
            return completedWithErrorsTitle
        case .cancelled:
            return cancelledTitle
        case .failed:
            return failedTitle
        case .idle, .preparing, .copying:
            return "Экспортирую"
        }
    }

    /// Выбирает цвет текста для успешного результата, отмены или ошибки.
    private var resultTitleColor: Color {
        isCompleted ? .green : .orange
    }

    /// Показывает долю завершённых файлов, как кольцо прогресса Live Activity.
    private var progressFraction: Double {
        return fraction(
            completed: progress.completedFiles,
            total: progress.totalFiles
        )
    }

    /// Возвращает значение прогресса в безопасном диапазоне от нуля до единицы.
    private func fraction(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    /// Форматирует процент для значения доступности компактного индикатора.
    private var progressPercentageText: String {
        "\(Int((progressFraction * 100).rounded()))%"
    }

    // MARK: - UI

    var body: some View {
        ZStack(alignment: .topTrailing) {
            // Основное содержимое остаётся отдельной кнопкой и открывает детали.
            // Кнопка закрытия размещается рядом, поэтому вложенных Button нет.
            Button(action: onTap) {
                HStack(spacing: 8) {
                    if isDismissibleResult {
                        Text(resultTitle)
                            .font(.subheadline)
                            .foregroundStyle(resultTitleColor)
                            .lineLimit(1)
                    } else {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Экспортирую")
                                .font(.subheadline)
                                .lineLimit(1)

                            Text(progress.sourceName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer(minLength: 8)

                    if !isCompleted {
                        ExportProgressRingView(progress: progressFraction)
                    }
                }
                // Резервируем место под крестик только в строке текста.
                // Кольцо сохраняет полную ширину панели во всех активных состояниях.
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: topRowHeight, alignment: .center)
                .padding(.trailing, isDismissibleResult ? 30 : 0)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isDismissibleResult {
                // В активной операции кнопка отсутствует: экспорт нельзя скрыть
                // до его завершения и случайно прервать отображение прогресса.
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: dismissIconSize, height: dismissIconSize)
                        .frame(
                            width: dismissButtonSize,
                            height: topRowHeight,
                            alignment: .trailing
                        )
                }
                .buttonStyle(.plain)
                // Область кнопки равна высоте верхней строки, поэтому крестик
                // центрируется рядом с текстом и не меняет ширину содержимого панели.
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
                : "\(progressPercentageText), Экспортирую"
        )
    }
}

/// Показывает процент завершённых файлов внутри кольца прогресса.
private struct ExportProgressRingView: View {

    /// Доля завершения операции в диапазоне от нуля до единицы.
    let progress: Double

    /// Строит кольцо с теми же цветом, направлением и процентом, что Live Activity.
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.secondary.opacity(0.28),
                    lineWidth: 3
                )

            Circle()
                .trim(from: 0, to: normalizedProgress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(
                        lineWidth: 3,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            Text(percentageText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(width: 40, height: 40)
        .accessibilityLabel("Прогресс экспорта")
        .accessibilityValue(percentageText)
    }

    /// Ограничивает значение, чтобы неполный или ошибочный снимок не ломал кольцо.
    private var normalizedProgress: Double {
        min(max(progress, 0), 1)
    }

    /// Форматирует долю операции для центральной подписи кольца.
    private var percentageText: String {
        "\(Int((normalizedProgress * 100).rounded()))%"
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

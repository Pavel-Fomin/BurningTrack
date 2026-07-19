//
//  TrackListLiveActivity.swift
//  TrackListLiveActivity
//
//  Отображение универсального прогресса операции на экране блокировки
//  и в Dynamic Island.
//
//  Created by Pavel Fomin on 19.07.2026.
//

import ActivityKit
import SwiftUI
import WidgetKit

/// Widget Extension, которая показывает длительные операции приложения.
@main
struct TrackListLiveActivity: Widget {

    /// Регистрирует конфигурацию ActivityKit и все поддерживаемые области интерфейса.
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ProgressActivityAttributes.self) { context in
            ProgressLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "arrow.up.circle.fill")
                        .accessibilityLabel("Операция выполняется")
                }

                DynamicIslandExpandedRegion(.trailing) {
                    ProgressLiveActivityPercentageView(
                        state: context.state,
                        compact: true
                    )
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.operationTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressLiveActivityTitleView(
                            attributes: context.attributes
                        )
                        ProgressLiveActivityCountView(
                            state: context.state
                        )
                        ProgressView(value: context.state.fractionCompleted)
                    }
                }
            } compactLeading: {
                Image(systemName: "arrow.up.circle.fill")
            } compactTrailing: {
                Text(context.state.percentageText)
                .monospacedDigit()
                .lineLimit(1)
            } minimal: {
                ProgressView(value: context.state.fractionCompleted)
                    .progressViewStyle(.circular)
            }
        }
    }
}

/// Основной экран Live Activity на экране блокировки.
private struct ProgressLiveActivityLockScreenView: View {

    /// Контекст ActivityKit со статическими и динамическими данными операции.
    let context: ActivityViewContext<ProgressActivityAttributes>

    /// Строит светлую карточку операции по референсу выбранного фрейма Figma.
    var body: some View {
        HStack(spacing: ProgressLiveActivityStyle.contentSpacing) {
            ProgressLiveActivityAppIconView()

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.operationTitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Text(context.attributes.subjectTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 12)

            ProgressLiveActivityProgressRingView(state: context.state)
        }
        .padding(.horizontal, ProgressLiveActivityStyle.horizontalPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: ProgressLiveActivityStyle.lockScreenHeight,
            maxHeight: ProgressLiveActivityStyle.lockScreenHeight
        )
    }
}

/// Иконка приложения в карточке на экране блокировки.
private struct ProgressLiveActivityAppIconView: View {

    /// Строит иконку приложения с тем же скруглением, что в макете.
    var body: some View {
        Image("TrackListLiveActivityIcon")
            .resizable()
            .scaledToFill()
            .frame(
                width: ProgressLiveActivityStyle.iconSide,
                height: ProgressLiveActivityStyle.iconSide
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: ProgressLiveActivityStyle.iconCornerRadius,
                    style: .continuous
                )
            )
    }
}

/// Кольцевой индикатор прогресса и процента выполнения в правой части карточки.
private struct ProgressLiveActivityProgressRingView: View {

    /// Динамический снимок операции.
    let state: ProgressActivityAttributes.ContentState

    /// Строит кольцо прогресса и процент выполнения внутри него.
    var body: some View {
        Gauge(value: state.fractionCompleted) {
            EmptyView()
        } currentValueLabel: {
            ProgressLiveActivityRingPercentageView(state: state)
        }
        .gaugeStyle(ProgressLiveActivityCircularGaugeStyle())
        .tint(ProgressLiveActivityStyle.progressColor)
        .frame(
            width: ProgressLiveActivityStyle.progressSide,
            height: ProgressLiveActivityStyle.progressSide
        )
        .accessibilityLabel("Прогресс операции")
    }
}

/// Стиль Gauge с общей геометрией кольца и центрального значения.
private struct ProgressLiveActivityCircularGaugeStyle: GaugeStyle {

    /// Формирует кольцо и его центральную подпись в едином контейнере.
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(
                    Color.secondary.opacity(0.28),
                    lineWidth: ProgressLiveActivityStyle.progressLineWidth
                )

            Circle()
                .trim(from: 0, to: normalizedValue(configuration.value))
                .stroke(
                    .tint,
                    style: StrokeStyle(
                        lineWidth: ProgressLiveActivityStyle.progressLineWidth,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))

            if let currentValueLabel = configuration.currentValueLabel {
                currentValueLabel
                    .frame(
                        maxWidth: .infinity,
                        maxHeight: .infinity,
                        alignment: .center
                    )
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// Ограничивает значение Gauge диапазоном кольцевого индикатора.
    private func normalizedValue(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// Процент выполнения, помещаемый в центр кольцевого индикатора.
private struct ProgressLiveActivityRingPercentageView: View {

    /// Динамический снимок операции.
    let state: ProgressActivityAttributes.ContentState

    /// Показывает процент без зависимости от скорости экспорта.
    var body: some View {
        Text(state.percentageText)
            .font(.caption2.weight(.medium))
            .foregroundStyle(.tint)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }
}

/// Визуальные параметры карточки, перенесённые из выбранного фрейма Figma.
private enum ProgressLiveActivityStyle {

    /// Высота выбранной карточки в макете.
    static let lockScreenHeight: CGFloat = 80

    /// Скругление выбранной карточки в макете.
    static let lockScreenCornerRadius: CGFloat = 48

    /// Горизонтальный внутренний отступ карточки.
    static let horizontalPadding: CGFloat = 18

    /// Расстояние между иконкой и текстовой группой.
    static let contentSpacing: CGFloat = 16

    /// Размер иконки приложения.
    static let iconSide: CGFloat = 48

    /// Скругление иконки приложения.
    static let iconCornerRadius: CGFloat = 14

    /// Размер кольцевого индикатора.
    static let progressSide: CGFloat = 48

    /// Толщина линии кольцевого индикатора.
    static let progressLineWidth: CGFloat = 3

    /// Системный акцентный цвет заполненной части кольцевого индикатора.
    static let progressColor = Color(
        red: 10 / 255,
        green: 132 / 255,
        blue: 255 / 255
    )
}

/// Заголовок операции с безопасным сокращением длинного имени объекта.
private struct ProgressLiveActivityTitleView: View {

    /// Статические данные текущей операции.
    let attributes: ProgressActivityAttributes

    /// Показывает название операции и объекта без полного пути.
    var body: some View {
        Text("\(attributes.operationTitle) «\(attributes.subjectTitle)»")
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.65)
    }
}

/// Счётчик завершённых и общего количества единиц операции.
private struct ProgressLiveActivityCountView: View {

    /// Динамический снимок операции.
    let state: ProgressActivityAttributes.ContentState

    /// Отображает счётчик без добавления технических пояснений.
    var body: some View {
        Text("\(state.completedUnits) из \(state.totalUnits)")
            .font(.title3.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
    }
}

/// Показывает процент выполнения в областях ограниченного размера.
private struct ProgressLiveActivityPercentageView: View {

    /// Динамический снимок операции.
    let state: ProgressActivityAttributes.ContentState

    /// Уменьшенный режим для ограниченного места Dynamic Island.
    let compact: Bool

    /// Подбирает размер текста для компактного и развёрнутого представления.
    var body: some View {
        Text(state.percentageText)
            .font(compact ? .caption : .body)
            .monospacedDigit()
    }
}

private extension ProgressActivityAttributes.ContentState {

    /// Доля выполнения, ограниченная для системных индикаторов прогресса.
    var fractionCompleted: Double {
        guard totalUnits > 0 else { return 0 }
        return min(
            max(Double(completedUnits) / Double(totalUnits), 0),
            1
        )
    }

    /// Процент выполнения для подписей в Live Activity.
    var percentageText: String {
        "\(Int((fractionCompleted * 100).rounded()))%"
    }
}

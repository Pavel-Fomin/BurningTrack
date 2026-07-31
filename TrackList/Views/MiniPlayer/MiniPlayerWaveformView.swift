//
//  MiniPlayerWaveformView.swift
//  TrackList
//
//  Визуальное представление waveform для мини-плеера.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import SwiftUI

/// Интерактивное представление waveform с уже подготовленными амплитудами от 0 до 1.
struct MiniPlayerWaveformView: View {

    /// Готовые нормализованные амплитуды от 0 до 1.
    let samples: [Double]
    /// Текущее время отображается в значении доступного элемента перемотки.
    let currentTime: TimeInterval
    /// Длительность сохраняется для доступности и единого контракта мини-плеера.
    let duration: TimeInterval
    /// Нормализованный progress вычисляется один раз родительским представлением.
    let progress: Double
    /// Обработчик запроса перемотки по нормализованной позиции.
    let onSeek: (Double) -> Void

    /// Временная позиция нужна только для отображения выбора пользователя во время drag.
    @State private var dragPreviewProgress: Double?
    /// Производные высоты готовятся только при новом waveform и не пересчитываются при изменении времени.
    @State private var barHeights: [CGFloat]

    init(
        samples: [Double],
        currentTime: TimeInterval,
        duration: TimeInterval,
        progress: Double,
        onSeek: @escaping (Double) -> Void
    ) {
        self.samples = samples
        self.currentTime = currentTime
        self.duration = duration
        self.progress = progress
        self.onSeek = onSeek
        _barHeights = State(
            initialValue: Self.makeBarHeights(
                from: samples
            )
        )
    }

    /// Геометрические значения сохраняют плотность waveform независимо от ширины конкретного устройства.
    private enum Metrics {
        static let minimumBarHeight: CGFloat = 3
        static let maximumBarHeight: CGFloat = 20
        static let waveformHeight: CGFloat = 20
        static let preferredBarSpacing: CGFloat = 1
    }

    var body: some View {
        GeometryReader { geometry in
            let layout = MiniPlayerWaveformLayout(
                sampleCount: barHeights.count,
                availableWidth: geometry.size.width,
                preferredBarSpacing: Metrics.preferredBarSpacing
            )

            let displayedProgress = dragPreviewProgress ?? progress

            ZStack(alignment: .leading) {
                waveformBars(
                    color: Color.secondary.opacity(0.45),
                    layout: layout
                )

                // Два слоя используют одни высоты; верхний обрезается только по фактическому progress.
                waveformBars(
                    color: Color.accentColor,
                    layout: layout
                )
                .frame(
                    width: layout.activeWaveformWidth(for: displayedProgress),
                    alignment: .leading
                )
                .clipped()
            }
            .frame(width: layout.waveformWidth, height: geometry.size.height)
            .contentShape(Rectangle())
            .miniPlayerWaveformSeekGesture(
                duration: duration,
                availableWidth: geometry.size.width,
                onProgressChanged: { ratio in
                    dragPreviewProgress = ratio
                },
                onSeek: onSeek,
                onEnded: {
                    dragPreviewProgress = nil
                }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Now Playing")
            .accessibilityValue(SharedPresentationText.duration(currentTime))
        }
        .frame(height: Metrics.waveformHeight)
        .onChange(of: samples) { _, newSamples in
            // Появление готовых амплитуд меняет только высоты столбиков и сохраняет фактический progress.
            barHeights = Self.makeBarHeights(
                from: newSamples
            )
        }
    }

    /// Отображает заранее рассчитанные высоты для нейтрального и активного слоёв без повторного преобразования samples.
    private func waveformBars(
        color: Color,
        layout: MiniPlayerWaveformLayout
    ) -> some View {
        HStack(alignment: .center, spacing: layout.barSpacing) {
            ForEach(barHeights.indices, id: \.self) { index in
                RoundedRectangle(
                    cornerRadius: min(layout.barWidth / 2, 2),
                    style: .continuous
                )
                .fill(color)
                .frame(width: layout.barWidth, height: barHeights[index])
            }
        }
        .frame(width: layout.waveformWidth, height: Metrics.waveformHeight)
    }

    /// Преобразует готовые амплитуды в визуальные высоты однократно для каждого нового набора samples.
    private static func makeBarHeights(from samples: [Double]) -> [CGFloat] {
        samples.map { sample in
            let normalizedSample = min(max(sample, 0), 1)
            return Metrics.minimumBarHeight +
                (Metrics.maximumBarHeight - Metrics.minimumBarHeight) * CGFloat(normalizedSample)
        }
    }

}

/// Добавляет единый горизонтальный seek-жест к готовой waveform и её заглушке.
struct MiniPlayerWaveformSeekGesture: ViewModifier {

    let duration: TimeInterval
    let availableWidth: CGFloat
    let onProgressChanged: (Double) -> Void
    let onSeek: (Double) -> Void
    let onEnded: () -> Void

    private enum Metrics {
        static let tapMaximumDistance: CGFloat = 8
    }

    func body(content: Content) -> some View {
        content.gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    guard isHorizontalDrag(value.translation),
                          let ratio = progress(forHorizontalLocation: value.location.x)
                    else {
                        return
                    }

                    onProgressChanged(ratio)
                }
                .onEnded { value in
                    defer { onEnded() }

                    guard isTap(value.translation) || isHorizontalDrag(value.translation),
                          let ratio = progress(forHorizontalLocation: value.location.x)
                    else {
                        return
                    }

                    // Координата жеста переводится в долю ширины и далее существующий callback — в секунды трека.
                    onSeek(ratio)
                }
        )
    }

    /// Не допускает seek при некорректной длительности или отсутствии ширины для расчёта координаты.
    private func progress(forHorizontalLocation locationX: CGFloat) -> Double? {
        guard MiniPlayerWaveformLayout.isSeekAvailable(for: duration),
              availableWidth > 0
        else {
            return nil
        }

        return MiniPlayerWaveformLayout(
            sampleCount: 0,
            availableWidth: availableWidth
        )
        .progress(forHorizontalLocation: locationX)
    }

    /// Вертикальный жест остаётся у карточки мини-плеера и не запускает перемотку waveform.
    private func isHorizontalDrag(_ translation: CGSize) -> Bool {
        abs(translation.width) > abs(translation.height)
    }

    /// Неподвижное касание считается seek, а заметное вертикальное движение остаётся у карточки мини-плеера.
    private func isTap(_ translation: CGSize) -> Bool {
        max(abs(translation.width), abs(translation.height)) <= Metrics.tapMaximumDistance
    }
}

extension View {

    /// Подключает общий seek-жест к индикаторам прогресса мини-плеера.
    func miniPlayerWaveformSeekGesture(
        duration: TimeInterval,
        availableWidth: CGFloat,
        onProgressChanged: @escaping (Double) -> Void,
        onSeek: @escaping (Double) -> Void,
        onEnded: @escaping () -> Void
    ) -> some View {
        modifier(
            MiniPlayerWaveformSeekGesture(
                duration: duration,
                availableWidth: availableWidth,
                onProgressChanged: onProgressChanged,
                onSeek: onSeek,
                onEnded: onEnded
            )
        )
    }
}

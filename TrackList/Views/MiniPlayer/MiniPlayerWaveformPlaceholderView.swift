//
//  MiniPlayerWaveformPlaceholderView.swift
//  TrackList
//
//  Нейтральная заглушка waveform для мини-плеера.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import SwiftUI

/// Отображает спокойную линию точек, пока готовая waveform недоступна.
struct MiniPlayerWaveformPlaceholderView: View {

    /// Текущее время определяет окрашенную часть точечной линии.
    let currentTime: TimeInterval
    /// Длительность определяет доступность seek и долю пройденного трека.
    let duration: TimeInterval
    /// Передаёт выбранную пользователем позицию в диапазоне от 0 до 1.
    let onSeek: (Double) -> Void

    /// Временная позиция отображает выбор пользователя до завершения перетаскивания.
    @State private var dragPreviewProgress: Double?

    /// Высота совпадает с контейнером готовой waveform, поэтому смена состояния не меняет разметку.
    static let containerHeight: CGFloat = 20
    /// Ширина каждой точки пустой формы остаётся постоянной на любом устройстве.
    static let dotWidth: CGFloat = 2
    /// Интервал между соседними точками пустой формы остаётся постоянным.
    static let dotSpacing: CGFloat = 2

    /// Возвращает максимальное число точек с фиксированной геометрией, которое помещается в контейнер.
    static func dotCount(for availableWidth: CGFloat) -> Int {
        guard availableWidth >= dotWidth else { return 0 }

        return Int((availableWidth + dotSpacing) / (dotWidth + dotSpacing))
    }

    /// Возвращает ширину линии из заданного числа точек с учётом интервалов между ними.
    static func lineWidth(for dotCount: Int) -> CGFloat {
        guard dotCount > 0 else { return 0 }

        return CGFloat(dotCount) * dotWidth +
            CGFloat(dotCount - 1) * dotSpacing
    }

    var body: some View {
        GeometryReader { geometry in
            let dotCount = Self.dotCount(for: geometry.size.width)
            let lineWidth = Self.lineWidth(for: dotCount)
            let leadingInset = max((geometry.size.width - lineWidth) / 2, 0)
            let progress = MiniPlayerWaveformLayout.progress(
                currentTime: currentTime,
                duration: duration
            )
            let displayedProgress = dragPreviewProgress ?? progress

            ZStack(alignment: .leading) {
                dots(
                    color: Color.secondary.opacity(0.45),
                    dotCount: dotCount,
                    leadingInset: leadingInset,
                    containerHeight: geometry.size.height
                )

                // Активный слой повторяет геометрию точек и обрезается по фактическому progress.
                dots(
                    color: Color.accentColor,
                    dotCount: dotCount,
                    leadingInset: leadingInset,
                    containerHeight: geometry.size.height
                )
                .frame(
                    width: geometry.size.width * CGFloat(displayedProgress),
                    alignment: .leading
                )
                .clipped()
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
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
        }
        .frame(height: Self.containerHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Now Playing")
        .accessibilityValue(SharedPresentationText.duration(currentTime))
    }

    /// Отображает нейтральный или пройденный слой точек с неизменной геометрией заглушки.
    private func dots(
        color: Color,
        dotCount: Int,
        leadingInset: CGFloat,
        containerHeight: CGFloat
    ) -> some View {
        ZStack {
            ForEach(0..<dotCount, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: Self.dotWidth, height: Self.dotWidth)
                    .position(
                        x: leadingInset + Self.dotWidth / 2 +
                            CGFloat(index) * (Self.dotWidth + Self.dotSpacing),
                        y: containerHeight / 2
                    )
            }
        }
        .frame(height: containerHeight)
    }
}

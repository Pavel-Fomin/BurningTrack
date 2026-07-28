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

            ZStack {
                ForEach(0..<dotCount, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary.opacity(0.45))
                        .frame(width: Self.dotWidth, height: Self.dotWidth)
                        .position(
                            x: leadingInset + Self.dotWidth / 2 +
                                CGFloat(index) * (Self.dotWidth + Self.dotSpacing),
                            y: geometry.size.height / 2
                        )
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(height: Self.containerHeight)
        .accessibilityHidden(true)
    }
}

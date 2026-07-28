//
//  MiniPlayerWaveformLayout.swift
//  TrackList
//
//  Математика геометрии waveform мини-плеера.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import CoreGraphics
import Foundation

/// Рассчитывает геометрию неподвижной waveform без зависимости от SwiftUI.
struct MiniPlayerWaveformLayout {

    /// Количество готовых амплитуд без создания или изменения массива.
    let sampleCount: Int
    /// Доступная ширина контейнера waveform.
    let availableWidth: CGFloat
    /// Предпочтительное расстояние между столбиками при достаточной ширине.
    let preferredBarSpacing: CGFloat

    init(
        sampleCount: Int,
        availableWidth: CGFloat,
        preferredBarSpacing: CGFloat = 1
    ) {
        self.sampleCount = max(sampleCount, 0)
        self.availableWidth = max(availableWidth, 0)
        self.preferredBarSpacing = max(preferredBarSpacing, 0)
    }

    /// Расстояние уменьшается на узкой ширине, чтобы все samples оставались видимыми.
    var barSpacing: CGFloat {
        guard sampleCount > 1 else { return 0 }

        let maximumSpacing = availableWidth / CGFloat(sampleCount * 2 - 1)
        return min(preferredBarSpacing, maximumSpacing)
    }

    /// Ширина вычисляется из доступного места после интервалов между всеми samples.
    var barWidth: CGFloat {
        guard sampleCount > 0 else { return 0 }

        let totalSpacing = CGFloat(sampleCount - 1) * barSpacing
        return max((availableWidth - totalSpacing) / CGFloat(sampleCount), 0)
    }

    /// Полная ширина waveform совпадает с шириной контейнера, когда есть хотя бы один sample.
    var waveformWidth: CGFloat {
        guard sampleCount > 0 else { return 0 }

        return CGFloat(sampleCount) * barWidth + CGFloat(sampleCount - 1) * barSpacing
    }

    /// Ширина активного слоя определяется только нормализованным progress и не меняет геометрию samples.
    func activeWaveformWidth(for progress: Double) -> CGFloat {
        waveformWidth * CGFloat(normalizedProgress(progress))
    }

    /// Преобразует горизонтальную координату жеста в долю длительности трека.
    func progress(forHorizontalLocation locationX: CGFloat) -> Double {
        guard availableWidth > 0 else { return 0 }

        return normalizedProgress(Double(locationX / availableWidth))
    }

    /// Нормализует время трека для окрашивания пройденной части waveform.
    static func progress(currentTime: TimeInterval, duration: TimeInterval) -> Double {
        guard duration.isFinite,
              duration > 0,
              currentTime.isFinite
        else {
            return 0
        }

        if currentTime <= 0 {
            return 0
        }

        if currentTime >= duration {
            return 1
        }

        return normalizedProgress(currentTime / duration)
    }

    /// Ограничивает любое внешнее значение прогресса допустимым диапазоном waveform.
    func normalizedProgress(_ progress: Double) -> Double {
        Self.normalizedProgress(progress)
    }

    /// Общая нормализация нужна и для времени, и для координаты жеста.
    static func normalizedProgress(_ progress: Double) -> Double {
        guard progress.isFinite else { return 0 }

        return min(max(progress, 0), 1)
    }
}

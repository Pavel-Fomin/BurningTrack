//
//  MiniPlayerProgressView.swift
//  TrackList
//
//  Нижняя часть мини-плеера (прогресс).
//
//  Роль:
//  - отображает текущее время и оставшееся время
//  - отображает waveform с прогрессом воспроизведения
//  - выполняет seek при перемотке
//
//  Created by Pavel Fomin on 08.02.2026.
//

import SwiftUI

struct MiniPlayerProgressView: View {

    let currentTime: TimeInterval
    let duration: TimeInterval
    /// Явное состояние передаётся ViewModel; View не читает кэш и не анализирует аудио.
    let waveformState: PlayerWaveformState
    let onSeek: (TimeInterval) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {

            Text(SharedPresentationText.duration(currentTime))
                .font(.caption2)
                .frame(width: 40, alignment: .leading)

            playbackIndicator
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 4)

            Text(SharedPresentationText.remainingDuration(duration - currentTime))
                .font(.caption2)
                .frame(width: 40, alignment: .trailing)
        }
        // Отделяем прогресс от информационной части мини-плеера дополнительным вертикальным пространством.
        .padding(.top, 14)
    }

    /// Представление определяет тип индикатора без чтения кэша или изменения состояния воспроизведения.
    private var waveformPresentation: MiniPlayerWaveformPresentation {
        MiniPlayerWaveformPresentation(waveformState: waveformState)
    }

    /// Выбирает визуальное представление прогресса; seek доступен независимо от наличия готовой waveform.
    @ViewBuilder
    private var playbackIndicator: some View {
        switch waveformPresentation {
        case let .waveform(samples):
            MiniPlayerWaveformView(
                samples: samples,
                currentTime: currentTime,
                duration: duration,
                progress: MiniPlayerWaveformLayout.progress(
                    currentTime: currentTime,
                    duration: duration
                ),
                onSeek: seek
            )
        case .placeholder:
            MiniPlayerWaveformPlaceholderView(
                currentTime: currentTime,
                duration: duration,
                onSeek: seek
            )
        }
    }

    /// Переводит выбранную позицию индикатора в секунды трека.
    private func seek(to ratio: Double) {
        guard MiniPlayerWaveformLayout.isSeekAvailable(for: duration) else { return }

        let normalizedRatio = MiniPlayerWaveformLayout.normalizedProgress(ratio)
        onSeek(normalizedRatio * duration)
    }
}

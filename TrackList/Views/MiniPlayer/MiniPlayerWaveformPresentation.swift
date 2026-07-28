//
//  MiniPlayerWaveformPresentation.swift
//  TrackList
//
//  Выбор индикатора воспроизведения в мини-плеере.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation

/// Явно сопоставляет состояние производных данных с отображением без чтения файлов во View.
enum MiniPlayerWaveformPresentation: Equatable {
    /// Контейнер waveform показывает нейтральный placeholder, пока нет готовых амплитуд.
    case placeholder
    /// Готовые амплитуды передаются в неподвижную waveform.
    case waveform([Double])

    init(waveformState: PlayerWaveformState) {
        switch waveformState {
        case .ready(let samples) where samples.isEmpty == false:
            self = .waveform(samples)
        case .loading,
             .unavailable,
             .ready,
             .failed:
            self = .placeholder
        }
    }
}

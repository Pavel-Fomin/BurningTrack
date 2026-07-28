//
//  PlayerWaveformState.swift
//  TrackList
//
//  Состояние waveform текущего трека плеера.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation

/// Явно описывает доступность производного waveform для текущего трека.
enum PlayerWaveformState: Equatable {
    /// Для текущего трека нет готового локального источника или waveform ещё не запрашивался.
    case unavailable
    /// Локальный источник уже подготовлен плеером, а waveform строится в фоне.
    case loading
    /// Готовые нормализованные амплитуды для отображения в мини-плеере.
    case ready([Double])
    /// Производные данные не удалось получить, но воспроизведение остаётся доступным.
    case failed
}

/// Фиксированные параметры waveform мини-плеера не зависят от геометрии конкретного View.
enum PlayerWaveformConfiguration {
    /// Стабильное число ячеек определяет единый формат кэша и более детальную форму мини-плеера.
    static let miniPlayerSampleCount = 128
}

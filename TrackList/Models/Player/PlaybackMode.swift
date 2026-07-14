//
//  PlaybackMode.swift
//  TrackList
//
//  Модель режимов воспроизведения.
//
//  Created by Pavel Fomin on 14.07.2026.
//

import Foundation

/// Режим повтора текущего контекста воспроизведения.
///
/// Raw value является частью постоянного формата SQLite и не должен зависеть
/// от порядка case в перечислении.
enum PlaybackRepeatMode: String, Codable, Equatable {
    /// После последнего трека воспроизведение останавливается.
    case off
    /// После последнего трека начинается первый трек текущего контекста.
    case all
    /// После завершения повторно запускается текущий трек.
    case one
}

/// Полное состояние режимов воспроизведения.
struct PlaybackMode: Equatable {
    /// Безопасный режим для первого запуска и повреждённых данных.
    static let defaultValue = PlaybackMode(
        isShuffleEnabled: false,
        repeatMode: .off
    )

    /// Включает отдельный случайный порядок индексов текущего контекста.
    var isShuffleEnabled: Bool
    /// Определяет поведение на границах текущего контекста.
    var repeatMode: PlaybackRepeatMode

    /// Устраняет недопустимую комбинацию Shuffle и Repeat.
    var normalized: PlaybackMode {
        guard isShuffleEnabled else { return self }

        return PlaybackMode(
            isShuffleEnabled: true,
            repeatMode: .off
        )
    }
}

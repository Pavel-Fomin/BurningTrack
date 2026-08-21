//
//  PlayerPreparedLocalFile.swift
//  TrackList
//
//  Подготовленный PlayerManager локальный файл текущего трека.
//
//  Created by Pavel Fomin on 28.07.2026.
//

import Foundation

/// Передаёт наружу только уже подготовленный и доступный локальный ресурс без раскрытия состояния AVPlayer.
struct PlayerPreparedLocalFile: Sendable {
    /// Identity запуска не позволяет старому запросу того же trackId изменить waveform нового запуска.
    let requestID: PlaybackRequestID
    /// Идентификатор трека, которому принадлежит подготовленный ресурс.
    let trackId: UUID
    /// Локальный URL, для которого PlayerManager уже удерживает необходимый доступ.
    let fileURL: URL
}

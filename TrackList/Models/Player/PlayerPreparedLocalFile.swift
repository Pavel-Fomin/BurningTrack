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
    /// Идентификатор трека, которому принадлежит подготовленный ресурс.
    let trackId: UUID
    /// Локальный URL, для которого PlayerManager уже удерживает необходимый доступ.
    let fileURL: URL
}

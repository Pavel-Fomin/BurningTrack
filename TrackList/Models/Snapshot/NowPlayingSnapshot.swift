//
//  NowPlayingSnapshot.swift
//  TrackList
//
//  Единый снимок данных для Control Center / Lock Screen.
//  Используется PlayerViewModel → PlayerManager.
//  Не содержит бизнес-логики.
//
//  Created by PavelFomin on 08.01.2026.
//

import Foundation
import CoreGraphics

struct NowPlayingSnapshot {
    /// Название трека для системной карточки воспроизведения.
    let title: String
    /// Исполнитель трека для системной карточки воспроизведения.
    let artist: String
    /// Альбом трека для системной карточки воспроизведения.
    let album: String?
    /// Обложка, подготовленная под Lock Screen / Control Center.
    let artwork: CGImage?
    /// Текущее время воспроизведения.
    let currentTime: TimeInterval
    /// Длительность текущего трека.
    let duration: TimeInterval
    /// Флаг активного воспроизведения.
    let isPlaying: Bool
}

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
    let title: String
    let artist: String
    let artwork: CGImage?
    let currentTime: TimeInterval
    let duration: TimeInterval
    let isPlaying: Bool
}

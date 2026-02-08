//
//  MiniPlayerState.swift
//  TrackList
//
//  Состояние мини-плеера.
//
//  Роль:
//  - хранит данные для отображения мини-плеера
//  - разделяет состояние на статическое и динамическое
//
//  ВАЖНО:
//  - static state меняется редко (смена трека, загрузка метаданных)
//  - progress state меняется часто (обновление времени, play/pause)
//
//  Created by Pavel Fomin on 08.02.2026.
//

import Foundation
import UIKit

// MARK: - MiniPlayerStaticState

struct MiniPlayerStaticState: Equatable {

    /// Идентификатор трека (используется для понимания смены трека)
    let trackId: UUID

    /// Название трека (готовое для UI)
    let title: String

    /// Исполнитель (готовое для UI)
    let artist: String

    /// Обложка трека (runtime, не сериализуется)
    let artwork: UIImage?
}

// MARK: - MiniPlayerProgressState

struct MiniPlayerProgressState: Equatable {

    /// Флаг воспроизведения
    let isPlaying: Bool

    /// Текущее время воспроизведения (секунды)
    let currentTime: Double

    /// Длительность трека (секунды)
    let duration: Double
}

// MARK: - MiniPlayerState

struct MiniPlayerState: Equatable {

    let staticState: MiniPlayerStaticState
    let progressState: MiniPlayerProgressState
}

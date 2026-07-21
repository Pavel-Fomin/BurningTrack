//
//  MiniPlayerState.swift
//  TrackList
//
//  Состояние мини-плеера.
//
//  Роль:
//  - явно описывает состояние отображения мини-плеера;
//  - хранит данные для состояний воспроизведения;
//  - позволяет добавлять новые состояния без изменения способа подключения View.
//
//  ВАЖНО:
//  - static state меняется редко (смена трека, загрузка метаданных);
//  - progress state меняется часто (обновление времени, play/pause).
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

    /// Исполнитель из metadata; отсутствие значения обрабатывается presentation-слоем.
    let artist: String?

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

/// Явное состояние отображения мини-плеера.
///
/// Состояние `empty` не скрывает View, а задаёт его содержимое. Благодаря этому
/// контейнер мини-плеера остаётся постоянной частью layout экрана.
enum MiniPlayerState: Equatable {

    /// Нет текущего трека.
    case empty

    /// Трек воспроизводится.
    case playing(
        staticState: MiniPlayerStaticState,
        progressState: MiniPlayerProgressState
    )

    /// Трек поставлен на паузу или воспроизведение ещё не началось.
    case paused(
        staticState: MiniPlayerStaticState,
        progressState: MiniPlayerProgressState
    )

    /// Трек или его данные загружаются.
    case loading(staticState: MiniPlayerStaticState?)

    /// Произошла ошибка воспроизведения.
    case error
}

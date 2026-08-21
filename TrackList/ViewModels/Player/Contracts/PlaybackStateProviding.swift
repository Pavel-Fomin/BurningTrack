//
//  PlaybackStateProviding.swift
//  TrackList
//
//  Контракты состояния воспроизведения для внешних feature.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Combine
import Foundation

/// Объясняет, почему текущая строка playback изменилась в рамках одного пользовательского сценария.
enum ActiveTrackChangeReason: Equatable {
    /// Смена произошла без явной навигации MiniPlayer, например при естественном завершении трека.
    case passive
    /// Пользователь нажал Previous или Next в MiniPlayer и ожидает центрирование совпадающего списка.
    case miniPlayerNavigation

    /// Показывает, должен ли presentation-слой подготовить одноразовый scroll intent.
    var requestsMatchingListCentering: Bool {
        self == .miniPlayerNavigation
    }
}

/// Одноразовый intent центрирования, уже привязанный к physical identity текущего displayable-трека.
struct AutomaticListScrollTrigger: Equatable, Identifiable {
    /// Отдельная identity исключает смешивание повторных переходов к одной строке.
    let id: UUID
    /// Идентификатор строки в текущем playback-контексте.
    let targetDisplayableId: UUID
    /// Контекст, которому принадлежит target identity.
    let targetContext: PlaybackContext
}

/// Неизменяемый снимок состояния воспроизведения для presentation-слоя.
/// Хранит только данные текущей строки и контекста, без команд, очереди и runtime metadata.
struct PlaybackStateSnapshot: Equatable {

    /// Идентификатор отображаемого элемента: строки очереди или треклиста.
    let currentDisplayableId: UUID?
    /// Идентификатор физического трека, если он доступен у текущего элемента.
    let currentTrackId: UUID?
    /// Обобщённый тип текущего контекста, необходимый существующим state builder-ам строк.
    let currentContext: PlaybackContext?
    /// Постоянный источник текущего контекста без раскрытия внутреннего PlayerViewModel.
    let currentContextSource: PlaybackContextSource?
    /// Признак активного воспроизведения.
    let isPlaying: Bool
    /// Причина последней смены активной строки без передачи playback-команд во внешние feature.
    let activeTrackChangeReason: ActiveTrackChangeReason
    /// Одноразовый intent для списка, доступный только после явной навигации MiniPlayer.
    let automaticListScrollTrigger: AutomaticListScrollTrigger?

    /// Создаёт совместимый playback-снимок и позволяет старым consumer-ам не передавать passive scroll-поля.
    init(
        currentDisplayableId: UUID?,
        currentTrackId: UUID?,
        currentContext: PlaybackContext?,
        currentContextSource: PlaybackContextSource?,
        isPlaying: Bool,
        activeTrackChangeReason: ActiveTrackChangeReason = .passive,
        automaticListScrollTrigger: AutomaticListScrollTrigger? = nil
    ) {
        self.currentDisplayableId = currentDisplayableId
        self.currentTrackId = currentTrackId
        self.currentContext = currentContext
        self.currentContextSource = currentContextSource
        self.isPlaying = isPlaying
        self.activeTrackChangeReason = activeTrackChangeReason
        self.automaticListScrollTrigger = automaticListScrollTrigger
    }
}

/// Предоставляет реактивное состояние воспроизведения внешним feature.
/// Контракт не содержит playback-команд, очередь, избранное, waveform, Now Playing и настройки.
/// Production-provider — PlayerViewModel; потребители не получают его конкретный тип.
@MainActor
protocol PlaybackStateProviding: AnyObject {

    /// Актуальный снимок состояния без необходимости подписки.
    var playbackState: PlaybackStateSnapshot { get }
    /// Идентификатор текущего отображаемого элемента.
    var currentDisplayableId: UUID? { get }
    /// Идентификатор физического текущего трека.
    var currentTrackId: UUID? { get }
    /// Обобщённый тип текущего playback-контекста.
    var currentContext: PlaybackContext? { get }
    /// Постоянный источник текущего playback-контекста.
    var currentContextSource: PlaybackContextSource? { get }
    /// Признак активного воспроизведения.
    var isPlaying: Bool { get }
    /// Единый поток изменений полного playback-состояния.
    var playbackStatePublisher: AnyPublisher<PlaybackStateSnapshot, Never> { get }
}

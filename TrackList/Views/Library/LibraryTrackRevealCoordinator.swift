//
//  LibraryTrackRevealCoordinator.swift
//  TrackList
//
//  Координирует reveal и active-track scroll внутри экрана треков фонотеки.
//  Принимает решения о готовности прокрутки, но не выполняет SwiftUI-эффекты.
//
//  Created by Pavel Fomin on 21.06.2026.
//

import Combine
import Foundation

/// Типизирует причину программной прокрутки фонотеки.
enum LibraryScrollRequest: Equatable {
    case reveal(LibraryTrackRevealScrollRequest)
    case activeTrack(UUID)

    /// Идентификатор строки, к которой нужно прокрутить список.
    var targetId: UUID {
        switch self {
        case .reveal(let request):
            return request.trackId
        case .activeTrack(let id):
            return id
        }
    }
}

/// Команда прокрутки к строке, подготовленная reveal coordinator.
struct LibraryTrackRevealScrollRequest: Equatable {
    /// Идентификатор строки трека, к которой нужно прокрутить список.
    let trackId: UUID

    /// Идентификатор одноразового reveal-запроса.
    let requestId: UUID
}

/// Результат обработки reveal-запроса.
enum LibraryTrackRevealDecision: Equatable {
    /// Reveal не требует действий со стороны View.
    case none

    /// Reveal ждёт завершения загрузки или появления строки в секциях.
    case waitForTracks

    /// Reveal-запрос обработан без прокрутки, потому что целевой строки нет.
    case complete(requestId: UUID)

    /// Нужно выполнить SwiftUI-прокрутку к целевой строке.
    case reveal(LibraryTrackRevealScrollRequest)
}

@MainActor
final class LibraryTrackRevealCoordinator: ObservableObject {

    // MARK: - State

    /// Текущий ожидающий reveal-запрос.
    @Published private var pendingRevealRequest: LibraryRevealRequest?

    /// Идентификатор строки, которая должна быть временно подсвечена.
    @Published private(set) var revealedTrackID: UUID?

    /// Идентификатор reveal-запроса, которому принадлежит текущая подсветка.
    private var revealedRequestId: UUID?

    /// Последний завершённый request, чтобы не обрабатывать повторную доставку.
    private var completedRequestId: UUID?

    /// Есть ли reveal-запрос, который ещё ждёт появления строки.
    var hasPendingRevealRequest: Bool {
        pendingRevealRequest != nil
    }

    /// Есть ли reveal scroll, который уже запрошен, но ещё не подтверждён View.
    private var hasUnperformedRevealScroll: Bool {
        guard let revealedRequestId else { return false }
        return completedRequestId != revealedRequestId
    }

    // MARK: - Init

    init(initialRequest: LibraryRevealRequest?) {
        pendingRevealRequest = initialRequest
    }

    // MARK: - Reveal lifecycle

    /// Принимает новый внешний reveal-запрос и возвращает решение для View.
    func receiveRevealRequest(
        _ request: LibraryRevealRequest?,
        trackSections: [TrackSection],
        didLoad: Bool,
        isLoading: Bool
    ) -> LibraryTrackRevealDecision {
        guard let request else {
            pendingRevealRequest = nil
            return .none
        }

        guard request.requestId != pendingRevealRequest?.requestId else {
            return .none
        }

        guard request.requestId != revealedRequestId else {
            return .none
        }

        guard request.requestId != completedRequestId else {
            return .none
        }

        pendingRevealRequest = request

        return evaluateReveal(
            trackSections: trackSections,
            didLoad: didLoad,
            isLoading: isLoading
        )
    }

    /// Повторно проверяет ожидающий reveal после изменения данных списка.
    func evaluateReveal(
        trackSections: [TrackSection],
        didLoad: Bool,
        isLoading: Bool
    ) -> LibraryTrackRevealDecision {
        guard let request = pendingRevealRequest else {
            return .none
        }

        let targetTrackId = request.targetTrackId
        let requestId = request.requestId

        guard hasTrack(id: targetTrackId, in: trackSections) else {
            guard didLoad && !isLoading else {
                return .waitForTracks
            }

            pendingRevealRequest = nil
            completedRequestId = requestId
            return .complete(requestId: requestId)
        }

        pendingRevealRequest = nil
        revealedTrackID = targetTrackId
        revealedRequestId = requestId

        return .reveal(
            LibraryTrackRevealScrollRequest(
                trackId: targetTrackId,
                requestId: requestId
            )
        )
    }

    /// Фиксирует, что View выполнила команду прокрутки для reveal-запроса.
    func markRevealScrollPerformed(
        _ request: LibraryTrackRevealScrollRequest
    ) -> UUID? {
        guard revealedTrackID == request.trackId else { return nil }
        guard revealedRequestId == request.requestId else { return nil }

        completedRequestId = request.requestId
        return request.requestId
    }

    /// Очищает подсветку, если она всё ещё относится к указанному request.
    func clearRevealHighlightIfCurrent(
        _ request: LibraryTrackRevealScrollRequest
    ) {
        guard revealedTrackID == request.trackId else { return }
        guard revealedRequestId == request.requestId else { return }

        revealedTrackID = nil
        revealedRequestId = nil
    }

    // MARK: - Active track scroll

    /// Возвращает запрос прокрутки к текущему треку, если reveal не имеет приоритета.
    func activeTrackScrollRequestIfNeeded(
        currentTrack: (any TrackDisplayable)?,
        currentContext: PlaybackContext?,
        trackSections: [TrackSection],
        hasPendingScrollRequest: Bool
    ) -> LibraryScrollRequest? {
        guard !hasPendingRevealRequest else { return nil }
        guard !hasUnperformedRevealScroll else { return nil }
        guard !hasPendingScrollRequest else { return nil }
        guard currentContext == .library else { return nil }
        guard let currentTrackId = currentTrack?.id else { return nil }
        guard hasTrack(id: currentTrackId, in: trackSections) else { return nil }

        return .activeTrack(currentTrackId)
    }

    // MARK: - Track lookup

    /// Проверяет, присутствует ли строка трека в текущих секциях экрана.
    func hasTrack(id: UUID, in trackSections: [TrackSection]) -> Bool {
        trackSections.contains { section in
            section.tracks.contains { $0.id == id }
        }
    }
}

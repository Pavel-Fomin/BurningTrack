//
//  TrackListsExternalOpenRequestManaging.swift
//  TrackList
//
//  Контракт одноразового внешнего открытия треклиста.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Даёт master-flow только необходимую часть межэкранной навигации без доступа к маршрутам фонотеки.
@MainActor
protocol TrackListsExternalOpenRequestManaging: AnyObject {

    /// Текущий одноразовый запрос открытия треклиста.
    var pendingTrackListOpenRequest: TrackListOpenRequest? { get }

    /// Очищает только запрос с совпадающей неизменяемой идентичностью.
    func clearTrackListOpenRequest(requestId: UUID)
}

extension NavigationCoordinator: TrackListsExternalOpenRequestManaging {}

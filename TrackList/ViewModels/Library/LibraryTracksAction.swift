//
//  LibraryTracksAction.swift
//  TrackList
//
//  Типизированные намерения экрана треков фонотеки.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import SwiftUI

/// Описывает намерения пользователя и lifecycle-события экрана, не перенося в маршрут SwiftUI-объекты.
enum LibraryTracksAction {
    case screenAppeared
    case refreshRequested
    /// Сообщает о фактическом закрытии folder destination владельцем navigation route.
    case screenClosed
    case sortModeSelected(LibraryTrackSortMode)
    case selectionStarted
    case selectionCancelled
    case trackSelectionToggled(UUID)
    case selectAllToggled
    case batchActionSelected(BulkTrackAction)
    case batchActionConfirmed
    case revealRequestReceived(LibraryRevealRequest?)
    case scenePhaseChanged(ScenePhase)
}

/// Позволяет host нижней панели вернуть подтверждение в экранный action-маршрут.
@MainActor
protocol LibraryTracksActionSending: AnyObject {
    func send(_ action: LibraryTracksAction)
}

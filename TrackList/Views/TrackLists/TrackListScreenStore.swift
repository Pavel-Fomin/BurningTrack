//
//  TrackListScreenStore.swift
//  TrackList
//
//  Удерживает стабильный graph detail-экрана одного треклиста.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Combine
import Foundation

/// Хранит ViewModel и ActionHandler на всё время жизни detail destination с одним route ID.
@MainActor
final class TrackListScreenStore: ObservableObject {
    /// Неизменяемая identity detail destination.
    let trackListId: UUID
    /// Владеет detail snapshot, load-once, retry и реактивными presentation-состояниями.
    let viewModel: TrackListViewModel
    /// Принимает typed lifecycle и пользовательские действия detail-экрана.
    let actionHandler: TrackListFlowActionHandler

    init(
        trackListId: UUID,
        viewModel: TrackListViewModel,
        actionHandler: TrackListFlowActionHandler
    ) {
        self.trackListId = trackListId
        self.viewModel = viewModel
        self.actionHandler = actionHandler
    }
}

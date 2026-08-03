//
//  LibraryTracksScreenState.swift
//  TrackList
//
//  Основное presentation-состояние списка треков фонотеки.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Данные нижней панели выбора без callback-ов и ссылок на ViewModel.
struct LibrarySelectionActionBarState: Equatable {
    let selectedCount: Int
    let isActionEnabled: Bool
    /// Отсутствие действия сохраняет обычный режим выбора без кнопки Apply.
    let pendingAction: BulkTrackAction?
}

/// Снимок редко меняющейся части Library Tracks.
/// Playback и iCloud остаются в отдельных контроллерах, чтобы не пересобирать список при каждом их изменении.
struct LibraryTracksScreenState: Equatable {
    var sections: [TrackSection] = []
    var isLoading = false
    var didLoad = false
    var sortMode: LibraryTrackSortMode
    var isSelecting = false
    var selectedTrackIDs = OrderedSelection<UUID>()
    var selectionActionBarState: LibrarySelectionActionBarState?
    var trackListMembershipsById: [UUID: [TrackListMembership]] = [:]
    /// Достаточно для View открыть существующий sheet; сам mutable flow остаётся в его handler-е.
    var isBatchFilenameRenameFlowActive = false

    /// Пустота считается только после завершения первой загрузки, поэтому loader не меняет UI-поведение.
    var isEmpty: Bool {
        didLoad && sections.allSatisfy { $0.tracks.isEmpty }
    }

    init(sortMode: LibraryTrackSortMode) {
        self.sortMode = sortMode
    }
}

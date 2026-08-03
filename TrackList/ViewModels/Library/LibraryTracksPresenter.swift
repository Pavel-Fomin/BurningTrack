//
//  LibraryTracksPresenter.swift
//  TrackList
//
//  Преобразует данные списка фонотеки в единое состояние экрана.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import Foundation

/// Принимает готовое presentation-состояние, не раскрывая Presenter-у SwiftUI View.
@MainActor
protocol LibraryTracksStateReceiving: AnyObject {
    func receive(_ state: LibraryTracksScreenState)
}

/// Собирает состояние Library Tracks из существующих секций, выбора и бейджей.
/// Не открывает sheet и не выполняет файловых операций: это остаётся в action/domain-слое.
@MainActor
final class LibraryTracksPresenter {
    private weak var output: (any LibraryTracksStateReceiving)?
    private let selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator

    init(
        output: any LibraryTracksStateReceiving,
        selectionActionBarCoordinator: LibrarySelectionActionBarCoordinator
    ) {
        self.output = output
        self.selectionActionBarCoordinator = selectionActionBarCoordinator
    }

    /// Формирует общий снимок, переиспользуя готовый builder нижней панели.
    func makeState(
        sections: [TrackSection],
        isLoading: Bool,
        didLoad: Bool,
        sortMode: LibraryTrackSortMode,
        selection: BulkSelectionState<UUID, BulkTrackAction>,
        membershipsById: [UUID: [TrackListMembership]],
        isBatchFilenameRenameFlowActive: Bool
    ) -> LibraryTracksScreenState {
        var state = LibraryTracksScreenState(sortMode: sortMode)
        state.sections = sections
        state.isLoading = isLoading
        state.didLoad = didLoad
        state.isSelecting = selection.isActive
        state.selectedTrackIDs = selection.selection
        state.trackListMembershipsById = membershipsById
        state.isBatchFilenameRenameFlowActive = isBatchFilenameRenameFlowActive
        state.selectionActionBarState = selectionActionBarCoordinator.makeState(
            isSelecting: selection.isActive,
            pendingAction: selection.pendingAction,
            selectedCount: selection.selectedCount,
            hasSelection: selection.hasSelection
        )
        return state
    }

    /// Публикует снимок через weak output, чтобы не образовывать цикл с ViewModel.
    func present(_ state: LibraryTracksScreenState) {
        output?.receive(state)
    }
}

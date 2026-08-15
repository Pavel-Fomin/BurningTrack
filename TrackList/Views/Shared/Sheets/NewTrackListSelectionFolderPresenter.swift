//
//  NewTrackListSelectionFolderPresenter.swift
//  TrackList
//
//  Собирает presentation-состояние папки выбора треков.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Объединяет готовые строки Library Tracks и selection-state до передачи в SwiftUI View.
@MainActor
struct NewTrackListSelectionFolderPresenter {
    /// Формирует состояние folder destination без вычислений selection в View.
    func makeState(
        tracksState: LibraryTracksScreenState,
        selectableSections: [TrackSelectableSectionState],
        selectedTrackIDs: Set<UUID>
    ) -> NewTrackListSelectionFolderScreenState {
        let visibleTrackIDs = tracksState.sections
            .flatMap(\.tracks)
            .map(\.id)
        let hasVisibleTracks = visibleTrackIDs.isEmpty == false

        return NewTrackListSelectionFolderScreenState(
            sections: selectableSections,
            visibleTracks: tracksState.sections.flatMap(\.tracks),
            isLoading: tracksState.isLoading,
            hasVisibleTracks: hasVisibleTracks,
            areAllVisibleTracksSelected: hasVisibleTracks
                && visibleTrackIDs.allSatisfy(selectedTrackIDs.contains)
        )
    }
}

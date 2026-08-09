//
//  AddToTrackListStateBuilder.swift
//  TrackList
//
//  Собирает presentation-состояние выбора треклиста назначения.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Преобразует доменные метаданные треклистов в готовое состояние Add To TrackList.
@MainActor
struct AddToTrackListStateBuilder {
    /// Собирает строки, доступность destination и состояние подтверждения.
    func build(
        trackLists: [TrackListMeta],
        selectedTrackListId: UUID?,
        excludedTrackListId: UUID?,
        isLoading: Bool,
        isSubmitting: Bool
    ) -> AddToTrackListState {
        let items = trackLists
            .sorted { $0.createdAt > $1.createdAt }
            .map { trackList in
                let isAvailable = trackList.id != excludedTrackListId

                return AddToTrackListItemState(
                    id: trackList.id,
                    title: TrackListPresentationText.title(
                        for: trackList.kind,
                        storedName: trackList.name
                    ),
                    isSelected: isAvailable && selectedTrackListId == trackList.id,
                    isAvailable: isAvailable
                )
            }
        let hasSelectedAvailableItem = items.contains {
            $0.id == selectedTrackListId && $0.isAvailable
        }

        return AddToTrackListState(
            items: items,
            selectedTrackListId: hasSelectedAvailableItem ? selectedTrackListId : nil,
            canSubmit: hasSelectedAvailableItem && !isLoading && !isSubmitting,
            isLoading: isLoading,
            isSubmitting: isSubmitting
        )
    }
}

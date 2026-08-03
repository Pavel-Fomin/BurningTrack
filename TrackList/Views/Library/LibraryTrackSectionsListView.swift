//
//  LibraryTrackSectionsListView.swift
//  TrackList
//
//  Отображает секции треков в папке (по дате).
//  Чистый UI-компонент — не содержит навигации.
//  Все переходы выполняются на уровне LibraryFolderView / LibraryScreen.
//
//  Created by Pavel Fomin on 08.08.2025.
//

import SwiftUI

struct LibraryTrackSectionsListView: View {

    let sections: [TrackSection]
    let allTracks: [LibraryTrack]
    let playbackSource: PlaybackContextSource?
    /// Текущая категория коллекции, переданная из типизированного источника списка.
    let currentCollectionCategory: LibraryCollectionCategory?

    let trackListMembershipsById: [UUID: [TrackListMembership]]
    
    let presentationHandler: LibraryTrackPresentationHandler
    let cloudAvailabilityStateStore: (UUID) -> CloudTrackAvailabilityRowStateStore
    let cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler
    
    /// Готовый снимок «Избранного» для presentation state строк.
    let favoriteTrackIds: Set<UUID>
    /// Один screen-local handler принимает все действия строк без создания объектов в body секции.
    let commandHandler: LibraryTrackCommandHandler
    let playbackStateController: LibraryTrackPlaybackStateController
    
    let revealedTrackID: UUID?
    let highlightedTrackID: UUID?
    let shouldShowTags: Bool
    let shouldShowTrackListMembership: Bool
    let shouldShowFileFormat: Bool
    
    let isSelecting: Bool
    
    let selectedTrackIDs: OrderedSelection<UUID>

    var body: some View {
        ForEach(sections, id: \.id) { section in
            LibraryTrackSectionView(
                id: section.id,
                title: LibraryPresentationText.trackSectionHeader(section.header),
                showsHeader: section.showsHeader,
                tracks: section.tracks,
                allTracks: allTracks,
                playbackSource: playbackSource,
                currentCollectionCategory: currentCollectionCategory,
                trackListMembershipsById: trackListMembershipsById,
                favoriteTrackIds: favoriteTrackIds,
                presentationHandler: presentationHandler,
                cloudAvailabilityStateStore: cloudAvailabilityStateStore,
                cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
                commandHandler: commandHandler,
                playbackStateController: playbackStateController,
                revealedTrackID: revealedTrackID,
                highlightedTrackID: highlightedTrackID,
                shouldShowTags: shouldShowTags,
                shouldShowTrackListMembership: shouldShowTrackListMembership,
                shouldShowFileFormat: shouldShowFileFormat,
                isSelecting: isSelecting,
                selectedTrackIDs: selectedTrackIDs
               
            )
        }
    }
}

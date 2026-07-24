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

    let trackListNamesById: [UUID: [String]]
    
    let metadataProvider: TrackMetadataProviding
    let cloudAvailabilityStateStore: (UUID) -> CloudTrackAvailabilityRowStateStore
    let cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler
    
    let playerViewModel: PlayerViewModel
    let playbackStateController: LibraryTrackPlaybackStateController
    let sheetManager: SheetManager
    
    let revealedTrackID: UUID?
    let highlightedTrackID: UUID?
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void
    let shouldShowTags: Bool
    let shouldShowTrackListMembership: Bool
    let shouldShowFileFormat: Bool
    
    let isSelecting: Bool
    
    @Binding var selection: OrderedSelection<UUID>

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
                trackListNamesById: trackListNamesById,
                playerViewModel: playerViewModel,
                metadataProvider: metadataProvider,
                cloudAvailabilityStateStore: cloudAvailabilityStateStore,
                cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
                sheetManager: sheetManager,
                playbackStateController: playbackStateController,
                revealedTrackID: revealedTrackID,
                highlightedTrackID: highlightedTrackID,
                onRenameTrack: onRenameTrack,
                shouldShowTags: shouldShowTags,
                shouldShowTrackListMembership: shouldShowTrackListMembership,
                shouldShowFileFormat: shouldShowFileFormat,
                isSelecting: isSelecting,
                selection: $selection
               
            )
        }
    }
}

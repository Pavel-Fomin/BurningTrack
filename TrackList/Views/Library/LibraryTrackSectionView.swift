//
//  LibraryTrackSectionView.swift
//  TrackList
//
//  Секция треков с заголовком.
//  Чистый UI — не содержит навигации.
//  Навигация обрабатывается уровнем выше (FolderView / LibraryScreen).
//
//  Created by Pavel Fomin on 07.07.2025.
//

import SwiftUI

struct LibraryTrackSectionView: View {

    let id: String
    let title: String
    let showsHeader: Bool
    
    let tracks: [LibraryTrack]
    let allTracks: [LibraryTrack]
    let playbackSource: PlaybackContextSource?

    let trackListNamesById: [UUID: [String]]

    let playerViewModel: PlayerViewModel
    
    let metadataProvider: TrackMetadataProviding
    let cloudAvailabilityStateStore: (UUID) -> CloudTrackAvailabilityRowStateStore
    let cloudAvailabilityActionHandler: LibraryCloudAvailabilityActionHandler
    let sheetManager: SheetManager
    let playbackStateController: LibraryTrackPlaybackStateController

    let revealedTrackID: UUID?
    let highlightedTrackID: UUID?
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void
    let shouldShowTags: Bool
    let shouldShowTrackListMembership: Bool
    let shouldShowFileFormat: Bool
    
    let isSelecting: Bool
    @Binding var selection: OrderedSelection<UUID>

    var body: some View {
        if showsHeader {
            Section(header: sectionHeader) {
                sectionRows
            }
            .id(id)
        } else {
            Section {
                sectionRows
            }
            .id(id)
        }
    }

    /// Заголовок секции вынесен из body, чтобы уменьшить сложность SwiftUI-выражения.
    private var sectionHeader: some View {
        Text(title)
            // Дата остаётся вторичным ориентиром относительно содержимого списка.
            .font(.subheadline)
            .id(id)
    }

    /// Строки секции используются в ветках с заголовком и без него.
    private var sectionRows: some View {
        ForEach(tracks, id: \.id) { track in
            row(for: track)
        }
    }

    /// Собирает строку трека с явными локальными значениями для ускорения type-check.
    private func row(for track: LibraryTrack) -> some View {
        let rowId: UUID = track.id
        let isRevealed: Bool = rowId == revealedTrackID
        let isSelected: Bool = selection.contains(rowId)
        let onToggleSelection: () -> Void = {
            selection.toggle(rowId)
        }
        let playbackHandler = LibraryTrackPlaybackHandler(
            playerViewModel: playerViewModel,
            source: playbackSource
        )
        let presentationHandler = LibraryTrackPresentationHandler(
            metadataProvider: metadataProvider
        )
        let rowState = presentationHandler.makeState(
            track: track,
            snapshot: presentationHandler.snapshot(for: track.trackId),
            isCurrent: playbackStateController.isCurrent(track),
            isPlaying: playbackStateController.isPlaying(track),
            isHighlighted: isRevealed || rowId == highlightedTrackID,
            trackListNames: trackListNamesById[track.trackId] ?? [],
            showsSelection: isSelecting,
            isSelected: isSelected,
            shouldShowTags: shouldShowTags,
            shouldShowTrackListMembership: shouldShowTrackListMembership,
            shouldShowFileFormat: shouldShowFileFormat,
            // iCloud-состояние приходит точечно в контейнер строки.
            cloudAvailabilityState: nil
        )
        let commandHandler = LibraryTrackCommandHandler(
            sheetManager: sheetManager,
            playbackHandler: playbackHandler,
            presentationHandler: presentationHandler,
            cloudAvailabilityActionHandler: cloudAvailabilityActionHandler,
            onToggleSelection: onToggleSelection,
            onRenameTrack: onRenameTrack
        )

        return LibraryTrackRowContainer(
            state: rowState,
            allTracks: allTracks,
            commandHandler: commandHandler,
            cloudAvailabilityStateStore: cloudAvailabilityStateStore(track.trackId)
        )
        .id(rowId)
    }
}

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

    let title: String
    
    let tracks: [LibraryTrack]
    let allTracks: [LibraryTrack]

    let trackListViewModel: TrackListViewModel
    let trackListNamesById: [UUID: [String]]

    let playerViewModel: PlayerViewModel
    
    let metadataProvider: TrackMetadataProviding

    let isScrollingFast: Bool
    let revealedTrackID: UUID?
    
    let isSelecting: Bool
    @Binding var selection: OrderedSelection<UUID>

    var body: some View {
        Section(header: sectionHeader) {
            ForEach(tracks, id: \.id) { track in
                row(for: track)
            }
        }
        .id(title)
    }

    /// Заголовок секции вынесен из body, чтобы уменьшить сложность SwiftUI-выражения.
    private var sectionHeader: some View {
        Text(title)
            .font(.headline)
            .id(title)
    }

    /// Собирает строку трека с явными локальными значениями для ускорения type-check.
    private func row(for track: LibraryTrack) -> some View {
        let rowId: UUID = track.id
        let isRevealed: Bool = rowId == revealedTrackID
        let isSelected: Bool = selection.contains(rowId)
        let onToggleSelection: () -> Void = {
            selection.toggle(rowId)
        }

        return LibraryTrackRowWrapper(
            track: track,
            allTracks: allTracks,
            trackListViewModel: trackListViewModel,
            trackListNamesById: trackListNamesById,
            metadataProvider: metadataProvider,
            isScrollingFast: isScrollingFast,
            isRevealed: isRevealed,
            showsSelection: isSelecting,
            isSelected: isSelected,
            onToggleSelection: onToggleSelection,
            playerViewModel: playerViewModel
        )
        .id(rowId)
    }
}

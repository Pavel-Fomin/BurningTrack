//
//  TrackSelectableRowWrapper.swift
//  TrackList
//
//  Обёртка для использования TrackRowView в режиме выбора треков.
//  Не содержит логики плеера и сторонних зависимостей.
//
//  Created by Pavel Fomin on 30.04.2026.
//

import SwiftUI
import UIKit

struct TrackSelectableRowWrapper: View {
    
    // MARK: - Input
    
    let track: LibraryTrack
    let isSelected: Bool
    let metadataProvider: TrackMetadataProviding
    let onToggleSelection: () -> Void
    
    // MARK: - Snapshot
    
    /// Runtime snapshot трека (единый источник метаданных)
    private var snapshot: TrackRuntimeSnapshot? {
        metadataProvider.snapshot(for: track.id)
    }
    
    /// Обложка трека (строится из snapshot.artworkData)
    private var artwork: UIImage? {
        guard let data = snapshot?.artworkData else { return nil }
        
        return ArtworkProvider.shared.image(
            trackId: track.id,
            artworkData: data,
            purpose: .trackList
        )
    }
    
    // MARK: - UI
    
    var body: some View {
        TrackRowView(
            track: track,
            isCurrent: false,
            isPlaying: false,
            isHighlighted: false,
            artwork: artwork,
            title: snapshot?.title ?? track.title,
            artist: snapshot?.artist ?? track.artist ?? "",
            duration: snapshot?.duration ?? track.duration,
            onRowTap: {
                onToggleSelection()
            },
            onArtworkTap: nil,
            showsSelection: true,
            isSelected: isSelected,
            onToggleSelection: onToggleSelection,
            selectionPlacement: .trailing
        )
        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
        .task(id: track.id) {
            metadataProvider.requestSnapshotIfNeeded(for: track.id)
        }
    }
}

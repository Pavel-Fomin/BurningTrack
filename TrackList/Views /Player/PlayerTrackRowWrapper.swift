//
//  PlayerTrackRowWrapper.swift
//  TrackList
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI
import UIKit

struct PlayerTrackRowWrapper: View {
    let track: any TrackDisplayable
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    
    @ObservedObject var playerViewModel: PlayerViewModel
    
    @EnvironmentObject var sheetManager: SheetManager
    
    // MARK: - Metadata
    
    /// Теги
    private var metadata: TrackMetadataCacheManager.CachedMetadata? {
        playerViewModel.metadata(for: track.id)
    }
    /// Обложка
    private var artwork: UIImage? {
        guard let data = metadata?.artworkData else { return nil }

        return ArtworkProvider.shared.image(
            trackId: track.id,
            artworkData: data,
            purpose: .trackList)
    }
    
    // MARK: - UI
    
    var body: some View {
            TrackRowView(
                track: track,
                isCurrent: isCurrent,
                isPlaying: isPlaying,
                isHighlighted: sheetManager.highlightedTrackID == track.id,
                artwork: artwork,
                title: metadata?.title ?? track.title ?? track.fileName,
                artist: metadata?.artist ?? track.artist ?? "",
                duration: metadata?.duration ?? track.duration,

                /// Правая зона — как и раньше
                onRowTap: onTap,

                /// Левая зона — экран "О треке"
                onArtworkTap: { sheetManager.present(.trackDetail(track)) }
            )
            .task(id: track.id) {
                playerViewModel.requestMetadataIfNeeded(for: track.id)
            }

            // MARK: - Свайпы плеера

            .swipeActions(edge: .trailing, allowsFullSwipe: false) {

                /// Удалить
                Button(role: .destructive) {
                    Task {
                        try await AppCommandExecutor.shared.removeTrackFromPlayer( trackId: track.id ) }
                } label: { Label("Удалить", systemImage: "trash")
}

                /// Показать в фонотеке
                Button {
                    SheetActionCoordinator.shared.handle(
                        action: .showInLibrary,
                        track: track,
                        context: .player)
                } label: { Label("Показать", systemImage: "scope") } .tint(.gray)

                // Переместить
                Button {
                    SheetActionCoordinator.shared.handle(
                        action: .moveToFolder,
                        track: track,
                        context: .player)
                } label: { Label("Переместить", systemImage: "arrow.right.doc.on.clipboard") } .tint(.blue)
            }
        }
    }

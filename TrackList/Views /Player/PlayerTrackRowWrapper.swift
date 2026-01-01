//
//  PlayerTrackRowWrapper.swift
//  TrackList
//
//  Created by Pavel Fomin on 03.08.2025.
//

import Foundation
import SwiftUI

struct PlayerTrackRowWrapper: View {
    let track: any TrackDisplayable
    let isCurrent: Bool
    let isPlaying: Bool
    let onTap: () -> Void
    
    @ObservedObject var playerViewModel: PlayerViewModel
    
    @State private var artwork: CGImage? = nil
    @EnvironmentObject var sheetManager: SheetManager
    
    private var metadata: TrackMetadataCacheManager.CachedMetadata? {
        playerViewModel.metadata(for: track.id)
    }
    
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

                // Правая зона — как и раньше
                onRowTap: onTap,

                // Левая зона — экран "О треке"
                onArtworkTap: {
                    sheetManager.present(.trackDetail(track))
                }
            )
            .task(id: track.id) {
                artwork = await ArtworkLoader.loadIfNeeded(
                    current: artwork,
                    trackId: track.id
                )
            }
            .task(id: track.id) {
                playerViewModel.requestMetadataIfNeeded(for: track.id)
            }

            // MARK: - Свайпы плеера

            .swipeActions(edge: .trailing, allowsFullSwipe: false) {

                // Удалить
                Button(role: .destructive) {
                    if let index = PlaylistManager.shared.tracks.firstIndex(where: { $0.id == track.id }) {
                        PlaylistManager.shared.remove(at: index)
                    }
                } label: {
                    Label("Удалить", systemImage: "trash")
                }

                // Показать в фонотеке
                Button {
                    SheetActionCoordinator.shared.handle(
                        action: .showInLibrary,
                        track: track,
                        context: .player
                    )
                } label: {
                    Label("Показать", systemImage: "scope")
                }
                .tint(.gray)

                // Переместить
                Button {
                    SheetActionCoordinator.shared.handle(
                        action: .moveToFolder,
                        track: track,
                        context: .player
                    )
                } label: {
                    Label("Переместить", systemImage: "arrow.right.doc.on.clipboard")
                }
                .tint(.blue)
            }
        }
    }

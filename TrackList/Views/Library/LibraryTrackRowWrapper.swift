//
//  LibraryTrackRowWrapper.swift
//  TrackList
//
//  Обёртка для TrackRowView с реакцией на playerViewModel.
//  Чистый UI-компонент — не содержит навигации.
//  NavigationCoordinator и маршруты здесь НЕ используются.
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI
import UIKit

struct LibraryTrackRowWrapper: View {
    
    let track: LibraryTrack
    let allTracks: [LibraryTrack]
    
    let trackListViewModel: TrackListViewModel
    let trackListNamesById: [UUID: [String]]
    
    let metadataProvider: TrackMetadataProviding
    
    let isScrollingFast: Bool
    let isRevealed: Bool
    
    let showsSelection: Bool
    let isSelected: Bool
    
    let onToggleSelection: () -> Void
    
    @ObservedObject var playerViewModel: PlayerViewModel
    @EnvironmentObject var sheetManager: SheetManager
    
    // MARK: - Player state
    
    private var isCurrent: Bool {
        playerViewModel.isCurrent(track, in: .library)
    }
    
    private var isPlaying: Bool {
        isCurrent && playerViewModel.isPlaying
    }
    
    private var trackListNames: [String] {
        trackListNamesById[track.id] ?? []
    }
    
    private var isHighlighted: Bool {
        sheetManager.highlightedTrackID == track.id
    }
    
    
    // MARK: - Metadata
    
    /// Теги
    private var metadata: TrackMetadataCacheManager.CachedMetadata? {
        metadataProvider.metadata(for: track.id)
    }
    /// Обложка
    private var artwork: UIImage? {
        guard let data = metadata?.artworkData else { return nil }
        
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
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            isHighlighted: isRevealed || isHighlighted,
            artwork: artwork,
            title: metadata?.title ?? track.title,
            artist: metadata?.artist ?? track.artist ?? "",
            duration: metadata?.duration ?? track.duration,
            onRowTap: {
                if isCurrent {
                    playerViewModel.togglePlayPause()
                } else {
                    playerViewModel.play(track: track, context: allTracks)
                }
            },
            onArtworkTap: {
                sheetManager.present(.trackDetail(track))
            },
            showsSelection: showsSelection,
            isSelected: isSelected,
            onToggleSelection: onToggleSelection,
            trackListNames: trackListNames
        )
        .task(id: track.id.uuidString + "|" + (isScrollingFast ? "1" : "0")) {
            metadataProvider.requestMetadataIfNeeded(for: track.id)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if !showsSelection {

                // Добавить в плеер
                Button {
                    Task {
                        try? await AppCommandExecutor.shared.addTrackToPlayer(
                            trackId: track.id
                        )
                    }
                } label: {
                    Label("В плеер", systemImage: "waveform")
                }
                .tint(.blue)

                // Добавить в треклист
                Button {
                    sheetManager.present(
                        .addToTrackList(
                            AddToTrackListSheetData(
                                track: track,
                                sourceTrackListId: nil
                            )
                        )
                    )
                } label: {
                    Label("В треклист", systemImage: "list.star")
                }
                .tint(.green)

                // Переместить
                Button {
                    SheetActionCoordinator.shared.handle(
                        action: .moveToFolder,
                        track: track,
                        context: .library
                    )
                } label: {
                    Label("Переместить", systemImage: "arrow.right.doc.on.clipboard")
                }
                .tint(.gray)
            }
        }
    }
}

private extension View {
        @ViewBuilder
        func swipeIf(
            _ enabled: Bool,
            @ViewBuilder actions: (Self) -> some View
        ) -> some View {
            if enabled {
                actions(self)
            } else {
                self
            }
        }
    }

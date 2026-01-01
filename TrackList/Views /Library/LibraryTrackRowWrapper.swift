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

struct LibraryTrackRowWrapper: View {

    let track: LibraryTrack
    let allTracks: [LibraryTrack]

    let trackListViewModel: TrackListViewModel
    let trackListNamesById: [UUID: [String]]

    let metadataProvider: TrackMetadataProviding

    let isScrollingFast: Bool
    let isRevealed: Bool

    @ObservedObject var playerViewModel: PlayerViewModel

    @EnvironmentObject var toast: ToastManager
    @EnvironmentObject var sheetManager: SheetManager

    @State private var artwork: CGImage? = nil

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
    
    private var metadata: TrackMetadataCacheManager.CachedMetadata? {
        metadataProvider.metadata(for: track.id)
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

            // Правая зона — воспроизведение / пауза
            onRowTap: {
                if isCurrent {
                    playerViewModel.togglePlayPause()
                } else {
                    playerViewModel.play(track: track, context: allTracks)
                }
            },

            // Левая зона — экран "О треке"
            onArtworkTap: {
                sheetManager.present(
                    .trackDetail(track)
                )
            },

            trackListNames: trackListNames
        )

        .task(id: track.id.uuidString + "|" + (isScrollingFast ? "1" : "0")) {

            // Обложка
            if !isScrollingFast && artwork == nil {
                let img = await ArtworkLoader.loadIfNeeded(
                    current: artwork,
                    trackId: track.id
                )
                if let img {
                    await MainActor.run { artwork = img }
                }
            }

            // Metadata
            metadataProvider.requestMetadataIfNeeded(for: track.id)
        }

        // MARK: - Системные свайпы (В плеер / В треклист / Ещё)

        .swipeActions(edge: .trailing, allowsFullSwipe: false) {

                    // Добавить в плеер
                    Button {
                        Task {
                            guard let resolved = await BookmarkResolver.url(forTrack: track.id) else { return }

                            let playerTrack = PlayerTrack(
                                id: track.id,
                                title: track.title,
                                artist: track.artist,
                                duration: track.duration,
                                fileName: resolved.lastPathComponent,
                                isAvailable: true
                            )

                            PlaylistManager.shared.tracks.append(playerTrack)
                            PlaylistManager.shared.saveToDisk()

                            toast.show(
                                ToastData(
                                    style: .track(
                                        title: track.title ?? track.fileName,
                                        artist: track.artist ?? ""
                                    ),
                                    artwork: track.artwork
                                )
                            )
                        }

                    } label: { Label("В плеер", systemImage: "waveform")
                    }
                    .tint(.blue)

                    // Добавить в треклист
                    Button {
                        sheetManager.present(
                            .addToTrackList(
                                AddToTrackListSheetData(track: track)
                            )
                        )
                    } label: { Label("В треклист", systemImage: "list.star")
                    }
                    .tint(.green)

                    // Переместить
                    Button {
                        SheetActionCoordinator.shared.handle(
                            action: .moveToFolder,
                            track: track,
                            context: .library
                        )
                    } label: { Label("Переместить", systemImage: "arrow.right.doc.on.clipboard")
                    }
                    .tint(.gray)
                }
            }
        }

//
//  PlayerTrackRowWrapper.swift
//  TrackList
//
//  Адаптирует подготовленную строку очереди плеера к общему представлению трека.
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI

struct PlayerTrackRowWrapper: View {
    
    // MARK: - Входные данные
    
    let row: PlayerTrackRowState
    let onTap: () -> Void
    let onUnavailableTap: (UUID) -> Void
    let onDeleteTrack: (UUID) -> Void
    let onShowInLibrary: (UUID) -> Void
    let onMoveToFolder: (UUID) -> Void
    let onAddToTrackList: (UUID) -> Void
    let onToggleFavorite: (UUID) -> Void
    let onGoToArtist: (UUID) -> Void
    let onGoToAlbum: (UUID) -> Void
    let onShareTrack: (UUID) -> Void
    let onCopyTrack: (UUID) -> Void
    let onEditTags: (UUID) -> Void
    let onArtworkTap: (UUID) -> Void
    let onRequestSnapshot: (UUID) -> Void
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void

    private func isMenuActionAvailable(
        _ action: TrackMenuAction
    ) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            action,
            source: row.track.source,
            context: .player
        )
    }
    
    // MARK: - Интерфейс
    
    var body: some View {
        TrackRowView(
            track: row.track,
            isCurrent: row.isCurrent,
            isPlaying: row.isPlaying,
            isHighlighted: row.isHighlighted,
            artworkRequest: row.artworkRequest,
            artworkBadgeState: row.artworkBadgeState,
            title: row.title,
            artist: row.artist,
            duration: row.duration,
            onRowTap: onTap,
            onUnavailableTap: {
                onUnavailableTap(row.id)
            },
            showsFileFormat: row.showsFileFormat
        ) {
            playerActionMenuContent
        }
        .task(id: row.trackId) {
            onRequestSnapshot(row.trackId)
        }

        // MARK: - Свайпы плеера

        .swipeActions(edge: .trailing, allowsFullSwipe: false) {

            /// Удалить
            if isMenuActionAvailable(.deleteFromPlayer) {
                Button(role: .destructive) {
                    onDeleteTrack(row.id)
                } label: {
                    Label("Remove from Player", systemImage: "trash")
                }
            }

            /// Показать в фонотеке
            if isMenuActionAvailable(.showInLibrary) {
                Button {
                    onShowInLibrary(row.id)
                } label: {
                    Label("Show in Library", systemImage: "magnifyingglass")
                }
                .tint(.gray)
            }

            /// Переместить
            if isMenuActionAvailable(.moveToFolder) {
                Button {
                    onMoveToFolder(row.id)
                } label: {
                    Label("Move", systemImage: "arrow.forward.folder")
                }
                .tint(.blue)
            }
        }
    }

    /// Меню действий строки плеера.
    @ViewBuilder
    private var playerActionMenuContent: some View {
        if isMenuActionAvailable(.details) {
            Button {
                onArtworkTap(row.id)
            } label: {
                Label("Track Info", systemImage: "info.circle")
            }
        }

        if isMenuActionAvailable(.toggleFavorite) {
            TrackFavoriteMenuContent(
                isFavorite: row.isFavorite,
                onToggle: {
                    onToggleFavorite(row.id)
                }
            )
        }

        if isMenuActionAvailable(.share) {
            Button {
                onShareTrack(row.id)
            } label: {
                Label(
                    TrackSharePresentationText.actionTitle,
                    systemImage: "square.and.arrow.up"
                )
            }
        }

        if isMenuActionAvailable(.copy) {
            Button {
                onCopyTrack(row.id)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }

        if isMenuActionAvailable(.showInLibrary) {
            Button {
                onShowInLibrary(row.id)
            } label: {
                Label("Show in Library", systemImage: "magnifyingglass")
            }
        }

        if isMenuActionAvailable(.moveToFolder) {
            // Пункт меню использует тот же flow перемещения, что и свайп строки.
            Button {
                onMoveToFolder(row.id)
            } label: {
                Label("Move", systemImage: "arrow.forward.folder")
            }
        }

        if isMenuActionAvailable(.addToTrackList) {
            Button {
                onAddToTrackList(row.id)
            } label: {
                Label("Add to Tracklist", systemImage: "list.star")
            }
        }

        TrackGoToDestinationMenuContent(
            canGoToArtist: isMenuActionAvailable(.goToArtist) &&
                row.collectionNavigationTarget?.artist != nil,
            canGoToAlbum: isMenuActionAvailable(.goToAlbum) &&
                row.collectionNavigationTarget?.album != nil,
            goToTitle: PlayerPresentationText.goTo,
            goToArtistTitle: PlayerPresentationText.goToArtist,
            goToAlbumTitle: PlayerPresentationText.goToAlbum,
            onGoToArtist: {
                onGoToArtist(row.id)
            },
            onGoToAlbum: {
                onGoToAlbum(row.id)
            }
        )

        if isMenuActionAvailable(.editTags) ||
            isMenuActionAvailable(.renameFile) {
            Menu {
                if isMenuActionAvailable(.editTags) {
                    Button {
                        onEditTags(row.id)
                    } label: {
                        Label("Tags", systemImage: "tag")
                    }
                }

                if isMenuActionAvailable(.renameFile) {
                    // Системная секция делает "Название файла" подписью, а не пунктом меню.
                    Section("File Name") {
                        Button {
                            onRenameTrack(row.id, .artistTitle)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.artistTitle
                                )
                            )
                        }

                        Button {
                            onRenameTrack(row.id, .titleArtist)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.titleArtist
                                )
                            )
                        }

                        Button {
                            onRenameTrack(row.id, .manual)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.manual
                                )
                            )
                        }
                    }
                }
            } label: {
                Label("Edit", systemImage: "square.and.pencil")
            }
        }

        if isMenuActionAvailable(.deleteFromPlayer) {
            Button(role: .destructive) {
                onDeleteTrack(row.id)
            } label: {
                Label("Remove from Player", systemImage: "trash")
            }
        }
    }
}

//
//  TrackListRowView.swift
//  TrackList
//
//  Строка трека в треклисте.
//   UI-КОМПОНЕНТ:
// - не содержит свайпов
// - не знает про SheetManager
// - не содержит навигации
// - все действия передаются через колбэки
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI

struct TrackListRowView: View {
    
    // MARK: - Входные данные
    
    let state: TrackListRowState
    let onTap: () -> Void
    let onUnavailableTap: () -> Void
    let onDelete: () -> Void
    let onShareTrack: () -> Void
    let onCopyTrack: () -> Void
    let onAddToPlayer: () -> Void
    let onToggleFavorite: () -> Void
    let onRenameTrack: (FileRenameStrategy) -> Void
    let onEditTags: () -> Void
    let onArtworkTap: () -> Void
    let onShowInLibrary: () -> Void
    let onMoveToFolder: () -> Void
    let onGoToArtist: () -> Void
    let onGoToAlbum: () -> Void

    /// Использует подготовленную capability строки без policy-вызова из View.
    private func isMenuActionAvailable(
        _ action: TrackMenuAction
    ) -> Bool {
        state.availableActions.contains(action)
    }
    
    // MARK: - Интерфейс
    
    var body: some View {
        TrackRowView(
            track: Track(
                listItemId: state.id,
                trackId: state.trackId,
                title: state.title,
                artist: state.artist,
                duration: state.duration,
                fileName: state.fileName,
                isAvailable: state.isAvailable,
                source: state.source
            ),
            isCurrent: state.isCurrent,
            isPlaying: state.isPlaying,
            isHighlighted: state.isHighlighted, /// Подсветка управляется wrapper'ом
            artworkRequest: state.artworkRequest,
            artworkBadgeState: state.artworkBadgeState,
            title: state.title,
            artist: state.artist,
            duration: state.duration,
            onRowTap: onTap,                    /// Правая зона — воспроизведение / пауза
            onUnavailableTap: onUnavailableTap,
            showsFileFormat: state.showsFileFormat
        ) {
            trackListActionMenuContent
        }
        
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets())
        .listRowBackground(Color.clear)
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
    }

    /// Меню действий строки треклиста.
    @ViewBuilder
    private var trackListActionMenuContent: some View {
        if isMenuActionAvailable(.details) {
            Button {
                onArtworkTap()
            } label: {
                Label("Track Info", systemImage: "info.circle")
            }
        }

        if isMenuActionAvailable(.toggleFavorite) {
            TrackFavoriteMenuContent(
                isFavorite: state.isFavorite,
                onToggle: onToggleFavorite
            )
        }

        if isMenuActionAvailable(.share) {
            Button {
                onShareTrack()
            } label: {
                Label(
                    TrackSharePresentationText.actionTitle,
                    systemImage: "square.and.arrow.up"
                )
            }
        }

        if isMenuActionAvailable(.copy) {
            Button {
                onCopyTrack()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
        }

        if isMenuActionAvailable(.addToPlayer) {
            Button {
                onAddToPlayer()
            } label: {
                Label("Add to Player", systemImage: "waveform")
            }
        }

        if isMenuActionAvailable(.showInLibrary) {
            Button {
                onShowInLibrary()
            } label: {
                Label("Show in Library", systemImage: "magnifyingglass")
            }
        }

        if isMenuActionAvailable(.moveToFolder) {
            Button {
                onMoveToFolder()
            } label: {
                Label("Move", systemImage: "arrow.forward.folder")
            }
        }

        TrackGoToDestinationMenuContent(
            canGoToArtist: isMenuActionAvailable(.goToArtist),
            canGoToAlbum: isMenuActionAvailable(.goToAlbum),
            goToTitle: TrackListPresentationText.goTo,
            goToArtistTitle: TrackListPresentationText.goToArtist,
            goToAlbumTitle: TrackListPresentationText.goToAlbum,
            onGoToArtist: onGoToArtist,
            onGoToAlbum: onGoToAlbum
        )

        if isMenuActionAvailable(.editTags) ||
            isMenuActionAvailable(.renameFile) {
            Menu {
                if isMenuActionAvailable(.editTags) {
                    Button {
                        onEditTags()
                    } label: {
                        Label("Tags", systemImage: "tag")
                    }
                }

                if isMenuActionAvailable(.renameFile) {
                    // Системная секция делает "Название файла" подписью, а не пунктом меню.
                    Section("File Name") {
                        Button {
                            onRenameTrack(.artistTitle)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.artistTitle
                                )
                            )
                        }

                        Button {
                            onRenameTrack(.titleArtist)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.titleArtist
                                )
                            )
                        }

                        Button {
                            onRenameTrack(.manual)
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

        if isMenuActionAvailable(.deleteFromTrackList) {
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Remove from Tracklist", systemImage: "trash")
            }
        }
    }
}

//
//  LibraryTrackActionMenuContent.swift
//  TrackList
//
//  Меню действий строки фонотеки.
//  Created by Pavel Fomin on 07.07.2026.
//

import SwiftUI

/// Единый состав ellipsis-меню для одиночного трека фонотеки.
struct LibraryTrackActionMenuContent: View {
    let labels: TrackActionMenuLabels
    let onDetails: () -> Void
    let onMoveToFolder: () -> Void
    let onAddToPlayer: () -> Void
    let onAddToTrackList: () -> Void
    let collectionNavigationTarget: TrackCollectionNavigationTarget?
    let onGoToArtist: () -> Void
    let onGoToAlbum: () -> Void
    let onEditTags: () -> Void
    let onRenameFile: (FileRenameStrategy) -> Void

    var body: some View {
        if isMenuActionAvailable(.details) {
            Button {
                onDetails()
            } label: {
                Label(labels.trackInfo, systemImage: "info.circle")
            }
        }

        if isMenuActionAvailable(.moveToFolder) {
            Button {
                onMoveToFolder()
            } label: {
                Label(labels.move, systemImage: "arrow.forward.folder")
            }
        }

        if isMenuActionAvailable(.addToPlayer) {
            Button {
                onAddToPlayer()
            } label: {
                Label(labels.addToPlayer, systemImage: "waveform")
            }
        }

        if isMenuActionAvailable(.addToTrackList) {
            Button {
                onAddToTrackList()
            } label: {
                Label(labels.addToTracklist, systemImage: "list.star")
            }
        }

        if isMenuActionAvailable(.goToArtist),
           collectionNavigationTarget?.artist != nil {
            Button {
                onGoToArtist()
            } label: {
                Label(
                    labels.goToArtist,
                    systemImage: LibraryCollectionCategory.artists.systemImage
                )
            }
        }

        if isMenuActionAvailable(.goToAlbum),
           collectionNavigationTarget?.album != nil {
            Button {
                onGoToAlbum()
            } label: {
                Label(
                    labels.goToAlbum,
                    systemImage: LibraryCollectionCategory.albums.systemImage
                )
            }
        }

        if isMenuActionAvailable(.editTags) ||
            isMenuActionAvailable(.renameFile) {
            Menu {
                if isMenuActionAvailable(.editTags) {
                    Button {
                        onEditTags()
                    } label: {
                        Label(labels.tags, systemImage: "tag")
                    }
                }

                if isMenuActionAvailable(.renameFile) {
                    // Системная секция делает "Название файла" подписью, а не пунктом меню.
                    Section(labels.fileName) {
                        Button {
                            onRenameFile(.artistTitle)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.artistTitle
                                )
                            )
                        }

                        Button {
                            onRenameFile(.titleArtist)
                        } label: {
                            Text(
                                FileRenamePresentationText.strategyTitle(
                                    for: FileRenameStrategy.titleArtist
                                )
                            )
                        }

                        Button {
                            onRenameFile(.manual)
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
                Label(labels.edit, systemImage: "square.and.pencil")
            }
        }
    }

    /// Доступность пунктов берётся из каноничных правил фонотеки.
    private func isMenuActionAvailable(_ action: TrackMenuAction) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            action,
            source: .library,
            context: .library
        )
    }
}

/// Подписи контекстного меню передаются вызывающим presentation-слоем.
struct TrackActionMenuLabels {
    let trackInfo: String
    let move: String
    let addToPlayer: String
    let addToTracklist: String
    let goToArtist: String
    let goToAlbum: String
    let tags: String
    let fileName: String
    let edit: String

}

//
//  PlayerTrackRowWrapper.swift
//  TrackList
//
//  Created by Pavel Fomin on 03.08.2025.
//

import SwiftUI

struct PlayerTrackRowWrapper: View {
    
    // MARK: - Input
    
    let row: PlayerTrackRowState                         /// Готовое состояние строки плеера
    let onTap: () -> Void                                /// Обработчик тапа по строке
    let onDeleteTrack: (UUID) -> Void                    /// Обработчик удаления элемента очереди
    let onShowInLibrary: (UUID) -> Void                  /// Обработчик показа элемента очереди в фонотеке
    let onMoveToFolder: (UUID) -> Void                   /// Обработчик перемещения элемента очереди в папку
    let onAddToTrackList: (UUID) -> Void                 /// Обработчик добавления элемента очереди в треклист
    let onCopyTrack: (UUID) -> Void                      /// Обработчик копирования iTunes-трека
    let onEditTags: (UUID) -> Void                       /// Обработчик редактирования тегов элемента очереди
    let onArtworkTap: (UUID) -> Void                     /// Обработчик пункта меню "О треке"
    let onRequestSnapshot: (UUID) -> Void                /// Обработчик запроса runtime snapshot трека
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void /// Обработчик переименования элемента очереди

    /// Проверяет доступность пункта меню для строки плеера.
    private func isMenuActionAvailable(
        _ action: TrackMenuAction
    ) -> Bool {
        TrackMenuActionAvailability.isAvailable(
            action,
            source: row.track.source,
            context: .player
        )
    }
    
    // MARK: - UI
    
    var body: some View {
        TrackRowView(
            track: row.track,
            isCurrent: row.isCurrent,
            isPlaying: row.isPlaying,
            isHighlighted: row.isHighlighted,
            artworkRequest: row.artworkRequest,
            title: row.title,
            artist: row.artist,
            duration: row.duration,
            onRowTap: onTap,
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
                    Label("Show in Library", systemImage: "scope")
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
                Label("Show in Library", systemImage: "scope")
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

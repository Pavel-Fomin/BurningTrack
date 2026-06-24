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
    let onEditTags: (UUID) -> Void                       /// Обработчик редактирования тегов элемента очереди
    let onArtworkTap: (UUID) -> Void                     /// Обработчик пункта меню "О треке"
    let onRequestSnapshot: (UUID) -> Void                /// Обработчик запроса runtime snapshot трека
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void /// Обработчик переименования элемента очереди
    
    // MARK: - UI
    
    var body: some View {
        TrackRowView(
            track: row.track,
            isCurrent: row.isCurrent,
            isPlaying: row.isPlaying,
            isHighlighted: row.isHighlighted,
            artwork: row.artwork,
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
            Button(role: .destructive) {
                onDeleteTrack(row.id)
            } label: {
                Label("Удалить", systemImage: "trash")
            }

            /// Показать в фонотеке
            Button {
                onShowInLibrary(row.id)
            } label: {
                Label("Показать", systemImage: "scope")
            }
            .tint(.gray)

            /// Переместить
            Button {
                onMoveToFolder(row.id)
            } label: {
                Label("Переместить", systemImage: "arrow.forward.folder")
            }
            .tint(.blue)
        }
    }

    /// Меню действий строки плеера.
    @ViewBuilder
    private var playerActionMenuContent: some View {
        Button {
            onArtworkTap(row.id)
        } label: {
            Label("О треке", systemImage: "info.circle")
        }

        Button {
            onShowInLibrary(row.id)
        } label: {
            Label("Показать в папке", systemImage: "scope")
        }

        // Пункт меню использует тот же flow перемещения, что и свайп строки.
        Button {
            onMoveToFolder(row.id)
        } label: {
            Label("Переместить", systemImage: "arrow.forward.folder")
        }

        Button {
            onAddToTrackList(row.id)
        } label: {
            Label("В треклист", systemImage: "list.star")
        }

        Menu {
            Button {
                onEditTags(row.id)
            } label: {
                Label("Теги", systemImage: "tag")
            }

            // Системная секция делает "Название файла" подписью, а не пунктом меню.
            Section("Название файла") {
                Button {
                    onRenameTrack(row.id, .artistTitle)
                } label: {
                    Text("Артист - Название")
                }

                Button {
                    onRenameTrack(row.id, .titleArtist)
                } label: {
                    Text("Название - Артист")
                }

                Button {
                    onRenameTrack(row.id, .manual)
                } label: {
                    Text("Вручную")
                }
            }
        } label: {
            Label("Редактировать", systemImage: "square.and.pencil")
        }

        Button(role: .destructive) {
            onDeleteTrack(row.id)
        } label: {
            Label("Удалить из плеера", systemImage: "trash")
        }
    }
}

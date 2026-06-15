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
    let onArtworkTap: (UUID) -> Void                     /// Обработчик тапа по обложке элемента очереди
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
            onArtworkTap: {
                onArtworkTap(row.id)
            },
            showsFileFormat: row.showsFileFormat
        )
        .trackFileRenameMenu(
            artist: row.renameArtist,
            title: row.renameTitle,
            isEnabled: true,
            onRename: { strategy in
                onRenameTrack(row.id, strategy)
            }
        )
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
                Label("Переместить", systemImage: "arrow.right.doc.on.clipboard")
            }
            .tint(.blue)
        }
    }
}

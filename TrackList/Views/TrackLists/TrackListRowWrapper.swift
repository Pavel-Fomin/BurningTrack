//
//  TrackListRowWrapper.swift
//  TrackList
//
//  Created by Pavel Fomin on 13.12.2025.
//

import SwiftUI
import Foundation

@MainActor
struct TrackListRowWrapper: View {

    // MARK: - Input

    let track: Track                                  /// Трек строки
    let index: Int                                    /// Индекс строки в треклисте
    let tracksContext: [Track]                        /// Контекст всех треков треклиста

    let metadataProvider: TrackMetadataProviding      /// Провайдер runtime snapshot

    let playerViewModel: PlayerViewModel              /// ViewModel плеера
    let onTap: (Track) -> Void                        /// Обработчик тапа по строке
    let onDelete: (IndexSet) -> Void                  /// Обработчик удаления строки
    
    @EnvironmentObject var sheetManager: SheetManager /// Менеджер шитов

    // MARK: - Snapshot

    /// Runtime snapshot трека
    private var snapshot: TrackRuntimeSnapshot? {
        metadataProvider.snapshot(for: track.id)
    }

    /// Трек для отображения с данными из snapshot
    private var displayTrack: Track {
        Track(
            id: track.id,
            title: snapshot?.title ?? track.title,
            artist: snapshot?.artist ?? track.artist,
            duration: snapshot?.duration ?? track.duration,
            fileName: snapshot?.fileName ?? track.fileName,
            isAvailable: snapshot?.isAvailable ?? track.isAvailable
        )
    }

    // MARK: - UI
    
    var body: some View {
        let isCurrent = playerViewModel.isCurrent(track, in: .trackList)
        let isPlaying = isCurrent && playerViewModel.isPlaying

        TrackListRowView(
            track: displayTrack,
            isCurrent: isCurrent,
            isPlaying: isPlaying,
            onTap: { onTap(track) },
            onDelete: { onDelete(IndexSet(integer: index)) },
            onArtworkTap: { sheetManager.present(.trackDetail(track)) },
            metadataProvider: metadataProvider
        )
        .task(id: track.id) {
            metadataProvider.requestSnapshotIfNeeded(for: track.id)
        }

        // Свайпы треклиста
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {

            /// Локальное действие — удалить из треклиста
            Button(role: .destructive) {
                onDelete(IndexSet(integer: index))
            } label: {
                Label("Удалить", systemImage: "trash")
            }

            /// Глобальное действие — показать в фонотеке
            Button {
                SheetActionCoordinator.shared.handle(
                    action: .showInLibrary,
                    track: track,
                    context: .tracklist
                )
            } label: {
                Label("Показать", systemImage: "scope")
            }
            .tint(.gray)

            // Глобальное действие — переместить
            Button {
                SheetActionCoordinator.shared.handle(
                    action: .moveToFolder,
                    track: track,
                    context: .tracklist
                )
            } label: {
                Label("Переместить", systemImage: "arrow.right.doc.on.clipboard")
            }
            .tint(.blue)
        }
    }
}

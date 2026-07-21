//
// PlayerView.swift
// TrackList
//
// Экран плеера со списком треков
//
// Created by Pavel Fomin on 14.07.2025.
//


import Foundation
import SwiftUI
struct PlayerView: View {
    let rows: [PlayerTrackRowState]
    let scrollTargetId: UUID?
    let onTrackTap: (UUID) -> Void
    let onMoveTracks: (IndexSet, Int) -> Void
    let onDeleteTrack: (UUID) -> Void
    let onShowInLibrary: (UUID) -> Void
    let onMoveToFolder: (UUID) -> Void
    let onAddToTrackList: (UUID) -> Void  /// Добавление элемента очереди в треклист
    let onCopyTrack: (UUID) -> Void       /// Копирование iTunes-трека из очереди
    let onEditTags: (UUID) -> Void        /// Редактирование тегов элемента очереди
    let onArtworkTap: (UUID) -> Void
    let onRequestSnapshot: (UUID) -> Void
    let onRenameTrack: (UUID, FileRenameStrategy) -> Void
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        ScrollViewReader { proxy in
            List {
                if rows.isEmpty {
                    ContentUnavailableView(
                        "Queue Is Empty",
                        systemImage: "music.note.list",
                        description: Text("No Tracks")
                    )
                } else {
                    PlayerRowsView(
                        rows: rows,
                        onTrackTap: onTrackTap,
                        onMoveTracks: onMoveTracks,
                        onDeleteTrack: onDeleteTrack,
                        onShowInLibrary: onShowInLibrary,
                        onMoveToFolder: onMoveToFolder,
                        onAddToTrackList: onAddToTrackList,
                        onCopyTrack: onCopyTrack,
                        onEditTags: onEditTags,
                        onArtworkTap: onArtworkTap,
                        onRequestSnapshot: onRequestSnapshot,
                        onRenameTrack: onRenameTrack
                    )
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .onAppear {
                scrollToCurrentTrackIfNeeded(using: proxy, animated: false)
            }
            .onChange(of: scrollTargetId) { _, _ in
                scrollToCurrentTrackIfNeeded(using: proxy, animated: true)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                scrollToCurrentTrackIfNeeded(using: proxy, animated: true)
            }
        }
    }
    private func scrollToCurrentTrackIfNeeded(using proxy: ScrollViewProxy, animated: Bool) {
        guard let scrollTargetId else { return }
        guard rows.contains(where: { $0.id == scrollTargetId }) else { return }
        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(scrollTargetId, anchor: .center)
            }
        } else {
            proxy.scrollTo(scrollTargetId, anchor: .center)
        }
    }
    // MARK: - Компонент строк плеера
    
    private struct PlayerRowsView: View {
        let rows: [PlayerTrackRowState]
        let onTrackTap: (UUID) -> Void
        let onMoveTracks: (IndexSet, Int) -> Void
        let onDeleteTrack: (UUID) -> Void
        let onShowInLibrary: (UUID) -> Void
        let onMoveToFolder: (UUID) -> Void
        let onAddToTrackList: (UUID) -> Void  /// Добавление элемента очереди в треклист
        let onCopyTrack: (UUID) -> Void       /// Копирование iTunes-трека из очереди
        let onEditTags: (UUID) -> Void        /// Редактирование тегов элемента очереди
        let onArtworkTap: (UUID) -> Void
        let onRequestSnapshot: (UUID) -> Void
        let onRenameTrack: (UUID, FileRenameStrategy) -> Void
        var body: some View {
            ForEach(rows) { row in
                PlayerTrackRowWrapper(
                    row: row,
                    onTap: {
                        onTrackTap(row.id)
                    },
                    onDeleteTrack: onDeleteTrack,
                    onShowInLibrary: onShowInLibrary,
                    onMoveToFolder: onMoveToFolder,
                    onAddToTrackList: onAddToTrackList,
                    onCopyTrack: onCopyTrack,
                    onEditTags: onEditTags,
                    onArtworkTap: onArtworkTap,
                    onRequestSnapshot: onRequestSnapshot,
                    onRenameTrack: onRenameTrack
                )
                .id(row.id)
            }
            .onMove { from, to in
                onMoveTracks(from, to)
            }
        }
    }
}

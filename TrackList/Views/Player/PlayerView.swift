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
    let automaticListScrollTrigger: AutomaticListScrollTrigger?
    let onTrackTap: (UUID) -> Void
    let onUnavailableTrackTap: (UUID) -> Void
    let onMoveTracks: (IndexSet, Int) -> Void
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
    /// Локальная UI-политика не раскрывает список или SwiftUI proxy в PlayerScreenViewModel.
    @StateObject private var automaticScrollCoordinator = AutomaticListScrollCoordinator()

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
                        onUnavailableTrackTap: onUnavailableTrackTap,
                        onMoveTracks: onMoveTracks,
                        onDeleteTrack: onDeleteTrack,
                        onShowInLibrary: onShowInLibrary,
                        onMoveToFolder: onMoveToFolder,
                        onAddToTrackList: onAddToTrackList,
                        onToggleFavorite: onToggleFavorite,
                        onGoToArtist: onGoToArtist,
                        onGoToAlbum: onGoToAlbum,
                        onShareTrack: onShareTrack,
                        onCopyTrack: onCopyTrack,
                        onEditTags: onEditTags,
                        onArtworkTap: onArtworkTap,
                        onRequestSnapshot: onRequestSnapshot,
                        onRenameTrack: onRenameTrack
                    )
                }
            }
            .listStyle(.plain)
            .globalBottomScrollReserve()
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .onAppear {
                requestInitialScrollIfNeeded()
            }
            .onChange(of: scrollTargetId) { _, _ in
                requestActiveTrackScrollIfNeeded()
            }
            .onChange(of: automaticListScrollTrigger) { _, trigger in
                requestExplicitPlaybackNavigationScrollIfNeeded(
                    trigger,
                    proxy: proxy
                )
            }
            .onChange(of: automaticScrollCoordinator.pendingScrollRequest) { _, request in
                handleScrollRequest(request, proxy: proxy)
            }
            .onScrollPhaseChange { _, newPhase in
                handleScrollRequest(
                    automaticScrollCoordinator.receiveScrollPhase(
                        ListScrollPhase(newPhase)
                    ),
                    proxy: proxy
                )
            }
        }
    }

    /// Отдельное правило initial appearance не повторяется при foreground или remount списка.
    private func requestInitialScrollIfNeeded() {
        automaticScrollCoordinator.requestInitialScrollIfNeeded(
            targetId: scrollTargetId,
            isTargetAvailable: rows.contains { $0.id == scrollTargetId }
        )
    }

    /// Текущий queue item может запросить auto-scroll только без ручного позиционирования.
    private func requestActiveTrackScrollIfNeeded() {
        automaticScrollCoordinator.requestActiveTrackScrollIfNeeded(
            targetId: scrollTargetId,
            isTargetAvailable: rows.contains { $0.id == scrollTargetId }
        )
    }

    /// Явная команда MiniPlayer центрирует только текущую строку очереди и может быть отложена coordinator-ом до idle.
    private func requestExplicitPlaybackNavigationScrollIfNeeded(
        _ trigger: AutomaticListScrollTrigger?,
        proxy: ScrollViewProxy
    ) {
        guard let trigger,
              trigger.targetContext == .player else {
            return
        }

        // Явное действие должно materialize в текущем View update, а не ждать второе наблюдение Published-состояния.
        handleScrollRequest(
            automaticScrollCoordinator.requestExplicitPlaybackNavigationScrollIfNeeded(
                triggerId: trigger.id,
                targetId: trigger.targetDisplayableId,
                isTargetAvailable: rows.contains { $0.id == trigger.targetDisplayableId }
            ),
            proxy: proxy
        )
    }

    /// Выполняет `scrollTo` на UI-стороне и подтверждает lifecycle coordinator только для своего request.
    private func handleScrollRequest(
        _ request: AutomaticListScrollCoordinator.Request?,
        proxy: ScrollViewProxy
    ) {
        guard let request else { return }
        guard rows.contains(where: { $0.id == request.targetId }) else {
            automaticScrollCoordinator.rejectScroll(request)
            return
        }
        guard automaticScrollCoordinator.beginScroll(request) else {
            return
        }

        if request.isAnimated {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(request.targetId, anchor: .center)
            }
        } else {
            proxy.scrollTo(request.targetId, anchor: .center)
        }

        automaticScrollCoordinator.finishProgrammaticScroll(
            isAnimated: request.isAnimated
        )
    }
    // MARK: - Компонент строк плеера
    
    private struct PlayerRowsView: View {
        let rows: [PlayerTrackRowState]
        let onTrackTap: (UUID) -> Void
        let onUnavailableTrackTap: (UUID) -> Void
        let onMoveTracks: (IndexSet, Int) -> Void
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
        var body: some View {
            ForEach(rows) { row in
                PlayerTrackRowWrapper(
                    row: row,
                    onTap: {
                        onTrackTap(row.id)
                    },
                    onUnavailableTap: onUnavailableTrackTap,
                    onDeleteTrack: onDeleteTrack,
                    onShowInLibrary: onShowInLibrary,
                    onMoveToFolder: onMoveToFolder,
                    onAddToTrackList: onAddToTrackList,
                    onToggleFavorite: onToggleFavorite,
                    onGoToArtist: onGoToArtist,
                    onGoToAlbum: onGoToAlbum,
                    onShareTrack: onShareTrack,
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

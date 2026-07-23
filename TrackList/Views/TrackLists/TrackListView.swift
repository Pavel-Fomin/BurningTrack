//
//  TrackListView.swift
//  TrackList
//
//  Вью для отображения списка треков
//
//  Created by Pavel Fomin on 29.04.2025.
//

import SwiftUI
import AVFoundation

struct TrackListView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    private let state: TrackListScreenState
    private let onAction: (TrackListAction) -> Void
    /// Запрашивает runtime snapshot трека для строки.
    private let onRequestSnapshot: (UUID) -> Void

    init(
        state: TrackListScreenState,
        onAction: @escaping (TrackListAction) -> Void,
        onRequestSnapshot: @escaping (UUID) -> Void
    ) {
        self.state = state
        self.onAction = onAction
        self.onRequestSnapshot = onRequestSnapshot
    }

    var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                List {
                    if state.rows.isEmpty {
                        ContentUnavailableView(
                            "No Tracks",
                            systemImage: "music.note"
                        )
                    } else {
                        TrackListRowsView(
                            rows: state.rows,
                            onRequestSnapshot: onRequestSnapshot,
                            onTap: { rowId in
                                onAction(.rowTapped(rowId: rowId))
                            },
                            onDelete: { rowId in
                                onAction(.deleteTrack(rowId: rowId))
                            },
                            onCopyTrack: { rowId in
                                onAction(.copyTrack(rowId: rowId))
                            },
                            onAddToPlayer: { rowId in
                                onAction(.addToPlayer(rowId: rowId))
                            },
                            onRenameTrack: { rowId, strategy in
                                onAction(
                                    .renameFile(
                                        rowId: rowId,
                                        strategy: strategy
                                    )
                                )
                            },
                            onEditTags: { rowId in
                                onAction(.editTags(rowId: rowId))
                            },
                            onArtworkTap: { rowId in
                                onAction(.artworkTapped(rowId: rowId))
                            },
                            onShowInLibrary: { rowId in
                                onAction(.showInLibrary(rowId: rowId))
                            },
                            onMoveToFolder: { rowId in
                                onAction(.moveToFolder(rowId: rowId))
                            },
                            onMove: { source, destination in
                                onAction(
                                    .moveTrack(
                                        from: source,
                                        to: destination
                                    )
                                )
                            }
                        )
                    }
                }
                
                .listStyle(.plain)
                .globalBottomScrollReserve()
                .scrollContentBackground(.hidden)
                .onAppear {
                    scrollToCurrentTrackIfNeeded(using: proxy, animated: false)
                }
                .onChange(of: state.scrollTargetRowId) { _, _ in
                    scrollToCurrentTrackIfNeeded(using: proxy, animated: true)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    scrollToCurrentTrackIfNeeded(using: proxy, animated: true)
                }
            }
        }
    }
    
    private func scrollToCurrentTrackIfNeeded(using proxy: ScrollViewProxy, animated: Bool) {
        guard let targetId = state.scrollTargetRowId else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.25)) {
                proxy.scrollTo(targetId, anchor: .center)
            }
        } else {
            proxy.scrollTo(targetId, anchor: .center)
        }
    }
}

            // MARK: - Компонент строк треков

            private struct TrackListRowsView: View {
                let rows: [TrackListRowState]
                let onRequestSnapshot: (UUID) -> Void
                let onTap: (UUID) -> Void
                let onDelete: (UUID) -> Void
                let onCopyTrack: (UUID) -> Void
                let onAddToPlayer: (UUID) -> Void
                let onRenameTrack: (UUID, FileRenameStrategy) -> Void
                let onEditTags: (UUID) -> Void
                let onArtworkTap: (UUID) -> Void
                let onShowInLibrary: (UUID) -> Void
                let onMoveToFolder: (UUID) -> Void
                let onMove: (IndexSet, Int) -> Void

                /// Проверяет доступность пункта меню для строки треклиста.
                private func isMenuActionAvailable(
                    _ action: TrackMenuAction,
                    for row: TrackListRowState
                ) -> Bool {
                    TrackMenuActionAvailability.isAvailable(
                        action,
                        source: row.source,
                        context: .trackList
                    )
                }

                var body: some View {
                    ForEach(rows) { row in
                        TrackListRowView(
                            state: row,
                            onTap: {
                                onTap(row.id)
                            },
                            onDelete: {
                                onDelete(row.id)
                            },
                            onCopyTrack: {
                                onCopyTrack(row.id)
                            },
                            onAddToPlayer: {
                                onAddToPlayer(row.id)
                            },
                            onRenameTrack: { strategy in
                                onRenameTrack(row.id, strategy)
                            },
                            onEditTags: {
                                onEditTags(row.id)
                            },
                            onArtworkTap: {
                                onArtworkTap(row.id)
                            },
                            onShowInLibrary: {
                                onShowInLibrary(row.id)
                            },
                            onMoveToFolder: {
                                onMoveToFolder(row.id)
                            }
                        )
                        .task(id: row.trackId) {
                            onRequestSnapshot(row.trackId)
                        }

                        // Свайпы треклиста
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {

                            /// Локальное действие — удалить из треклиста
                            if isMenuActionAvailable(
                                .deleteFromTrackList,
                                for: row
                            ) {
                                Button(role: .destructive) {
                                    onDelete(row.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }

                            /// Глобальное действие — показать в фонотеке
                            if isMenuActionAvailable(
                                .showInLibrary,
                                for: row
                            ) {
                                Button {
                                    onShowInLibrary(row.id)
                                } label: {
                                    Label("Show in Library", systemImage: "magnifyingglass")
                                }
                                .tint(.gray)
                            }

                            // Глобальное действие — переместить
                            if isMenuActionAvailable(
                                .moveToFolder,
                                for: row
                            ) {
                                Button {
                                    onMoveToFolder(row.id)
                                } label: {
                                    Label("Move", systemImage: "arrow.forward.folder")
                                }
                                .tint(.blue)
                            }
                        }
                        .id(row.id)
                    }
                    .onMove(perform: onMove)
                }
            }

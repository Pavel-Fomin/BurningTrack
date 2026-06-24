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
                    TrackListRowsView(
                        rows: state.rows,
                        onRequestSnapshot: onRequestSnapshot,
                        onTap: { rowId in
                            onAction(.rowTapped(rowId: rowId))
                        },
                        onDelete: { rowId in
                            onAction(.deleteTrack(rowId: rowId))
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
                
                .listStyle(.plain)
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
                let onRenameTrack: (UUID, FileRenameStrategy) -> Void
                let onEditTags: (UUID) -> Void
                let onArtworkTap: (UUID) -> Void
                let onShowInLibrary: (UUID) -> Void
                let onMoveToFolder: (UUID) -> Void
                let onMove: (IndexSet, Int) -> Void

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
                            Button(role: .destructive) {
                                onDelete(row.id)
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }

                            /// Глобальное действие — показать в фонотеке
                            Button {
                                onShowInLibrary(row.id)
                            } label: {
                                Label("Показать", systemImage: "scope")
                            }
                            .tint(.gray)

                            // Глобальное действие — переместить
                            Button {
                                onMoveToFolder(row.id)
                            } label: {
                                Label("Переместить", systemImage: "arrow.forward.folder")
                            }
                            .tint(.blue)
                        }
                        .id(row.id)
                    }
                    .onMove(perform: onMove)
                }
            }

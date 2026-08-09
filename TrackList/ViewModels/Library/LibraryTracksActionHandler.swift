//
//  LibraryTracksActionHandler.swift
//  TrackList
//
//  Маршрутизация действий экрана треков фонотеки.
//
//  Created by Pavel Fomin on 02.08.2026.
//

import SwiftUI

/// Принимает намерения экрана и передаёт их существующему screen-flow без доступа к View.
@MainActor
final class LibraryTracksActionHandler {
    private weak var output: (any LibraryTracksActionHandlingOutput)?

    init(output: any LibraryTracksActionHandlingOutput) {
        self.output = output
    }

    /// Сохраняет единственную точку входа действий, а асинхронные сценарии оставляет у screen-flow.
    func handle(_ action: LibraryTracksAction) {
        switch action {
        case .screenAppeared:
            Task { [weak output] in
                await output?.loadTracksIfNeeded()
            }
        case .screenClosed:
            output?.cancelSelection()
        case .refreshRequested:
            Task { [weak output] in
                await output?.refreshTracks()
            }
        case .sortModeSelected(let sortMode):
            Task { [weak output] in
                await output?.selectSortMode(sortMode)
            }
        case .selectionStarted:
            output?.startSelection()
        case .selectionCancelled:
            output?.cancelSelection()
        case .trackSelectionToggled(let trackId):
            output?.toggleSelection(for: trackId)
        case .selectAllToggled:
            output?.toggleSelectAll()
        case .batchActionSelected(let action):
            output?.selectBatchAction(action)
        case .batchActionConfirmed:
            output?.confirmBatchAction()
        case .revealRequestReceived,
             .scenePhaseChanged:
            // Reveal и scene phase дают View только решение для SwiftUI-эффекта.
            break
        }
    }
}

/// Узкий output action handler-а сохраняет ViewModel владельцем опубликованного screen state.
@MainActor
protocol LibraryTracksActionHandlingOutput: AnyObject {
    func loadTracksIfNeeded() async
    func refreshTracks() async
    func selectSortMode(_ mode: LibraryTrackSortMode) async
    func startSelection()
    func cancelSelection()
    func toggleSelection(for trackId: UUID)
    func toggleSelectAll()
    func selectBatchAction(_ action: BulkTrackAction)
    func confirmBatchAction()
}

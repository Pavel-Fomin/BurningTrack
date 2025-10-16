//
//  SheetManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 29.07.2025.
//

import Foundation
import SwiftUI

struct TrackActionsSheetData: Identifiable, Equatable {
    let id = UUID()
    let track: any TrackDisplayable
    let context: TrackContext
    
    /// Доступные действия для текущего контекста
    var actions: [TrackAction] {
        switch context {
        case .library:
            return [.moveToFolder, .showInfo]   // без "показать в фонотеке"
        case .player:
            return [.showInLibrary, .moveToFolder, .showInfo]
        case .tracklist:
            return [.showInLibrary, .moveToFolder, .showInfo]
        }
    }
    
    static func == (lhs: TrackActionsSheetData, rhs: TrackActionsSheetData) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class SheetManager: ObservableObject {
    static let shared = SheetManager()

    @Published var trackToAdd: LibraryTrack?
    @Published var trackActionsSheet: TrackActionsSheetData?
    @Published var highlightedTrackID: UUID?
    
    private var presentationTask: Task<Void, Never>?

    private init() {}

    func open(track: LibraryTrack) {
        // Если текущий трек уже открыт — ничего не делаем
        if let current = trackToAdd, current.id == track.id {
            return
        }

        // Отменяем предыдущую задачу показа, если она ещё в процессе
        presentationTask?.cancel()

        // Запускаем новую задачу показа с задержкой
        presentationTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }

            trackToAdd = track
        }
    }

    func close() {
        presentationTask?.cancel()
        trackToAdd = nil
        trackActionsSheet = nil
        highlightedTrackID = nil
    }
    
    func presentTrackActions(track: any TrackDisplayable, context: TrackContext) {
        highlightedTrackID = track.id
        trackActionsSheet = TrackActionsSheetData(track: track, context: context)
    }
    
    func closeAllSheets() {
        trackActionsSheet = nil
        trackToAdd = nil
        highlightedTrackID = nil
    }
}

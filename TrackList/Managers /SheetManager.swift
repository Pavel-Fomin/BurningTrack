//
//  SheetManager.swift
//  TrackList
//
//  Created by Pavel Fomin on 29.07.2025.
//

import Foundation
import SwiftUI

@MainActor
final class SheetManager: ObservableObject {
    static let shared = SheetManager()
    private var presentationTask: Task<Void, Never>?
    
    @Published var renameSheet: RenameSheetData?
    @Published var trackToAdd: LibraryTrack?
    @Published var presentedSheet: PresentedSheet?
    
    struct RenameSheetData: Identifiable {
        let id = UUID()
        let url: URL
        let onRename: (String) -> Void
    }

    enum PresentedSheet: Identifiable, Equatable {
        case renameFolder(url: URL, onRename: (String) -> Void)
        case moveFolder(sourceURL: URL, availableFolders: [URL], onMove: (URL) -> Void)

        var id: String {
            switch self {
            case .renameFolder(let url, _): return "rename:\(url.path)"
            case .moveFolder(let sourceURL, _, _): return "move:\(sourceURL.path)"
            }
        }

        static func == (lhs: PresentedSheet, rhs: PresentedSheet) -> Bool {
            switch (lhs, rhs) {
            case (.renameFolder(let l, _), .renameFolder(let r, _)):
                return l == r
            case (.moveFolder(let l, _, _), .moveFolder(let r, _, _)):
                return l == r
            default:
                return false
            }
        }
    }

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
    }

    func presentRenameFolder(for url: URL, onRename: @escaping (String) -> Void) {
        presentedSheet = .renameFolder(url: url, onRename: onRename)
    }

    func dismiss() {
        presentedSheet = nil
    }
    
    func presentRename(url: URL, onRename: @escaping (String) -> Void) {
        renameSheet = RenameSheetData(url: url, onRename: onRename)
    }
    
    func presentMoveSheet(
        sourceURL: URL,
        availableFolders: [URL],
        onMove: @escaping (URL) -> Void
    ) {
        presentedSheet = .moveFolder(
            sourceURL: sourceURL,
            availableFolders: availableFolders,
            onMove: onMove
        )
    }
}

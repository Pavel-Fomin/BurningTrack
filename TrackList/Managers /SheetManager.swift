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

    @Published var trackToAdd: LibraryTrack?
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
    }
}

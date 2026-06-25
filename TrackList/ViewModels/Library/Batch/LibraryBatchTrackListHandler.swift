//
//  LibraryBatchTrackListHandler.swift
//  TrackList
//
//  Обрабатывает массовое добавление треков фонотеки в треклист.
//
//  Создано Codex 25.06.2026.
//

import Foundation

/// Открывает batch-flow добавления выбранных треков фонотеки в треклист.
/// Не хранит selection и не дублирует UI выбора треклиста.
@MainActor
final class LibraryBatchTrackListHandler {

    // MARK: - Зависимости

    private let sheetManager: SheetManager
    private let tracksProvider: @MainActor () -> [LibraryTrack]

    // MARK: - Инициализация

    init(
        sheetManager: SheetManager? = nil,
        tracksProvider: @escaping @MainActor () -> [LibraryTrack]
    ) {
        self.sheetManager = sheetManager ?? .shared
        self.tracksProvider = tracksProvider
    }

    // MARK: - Публичные методы

    /// Открывает существующий sheet выбора треклиста для выбранных треков.
    func startAddToTrackList(with pendingAction: PendingBulkTrackAction) {
        guard !pendingAction.isEmpty else { return }

        let selectedTracks = selectedLibraryTracks(
            for: pendingAction.trackIDs
        )
        guard !selectedTracks.isEmpty else { return }

        sheetManager.presentBatchAddToTrackList(for: selectedTracks)
    }

    // MARK: - Приватные методы

    /// Возвращает выбранные LibraryTrack в порядке исходного selection.
    private func selectedLibraryTracks(for trackIds: [UUID]) -> [LibraryTrack] {
        let tracksById = Dictionary(
            uniqueKeysWithValues: tracksProvider().map { track in
                (track.trackId, track)
            }
        )

        return trackIds.compactMap { trackId in
            tracksById[trackId]
        }
    }
}

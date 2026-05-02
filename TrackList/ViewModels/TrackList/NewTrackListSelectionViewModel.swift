//
//  NewTrackListSelectionViewModel.swift
//  TrackList
//
//  Состояние выбора треков для создания нового треклиста.
//
//  Created by Pavel Fomin on 29.04.2026.
//

import Foundation

@MainActor
final class NewTrackListSelectionViewModel: ObservableObject {

    // MARK: - State

    /// Выбранные треки по id.
    /// Храним сами LibraryTrack, чтобы после выбора сразу создать треклист.
    @Published private(set) var selectedTracksById: [UUID: LibraryTrack] = [:]

    /// Количество выбранных треков.
    var selectedCount: Int {
        selectedTracksById.count
    }

    /// Массив выбранных треков.
    var selectedTracks: [LibraryTrack] {
        Array(selectedTracksById.values)
    }

    // MARK: - Selection

    /// Проверяет, выбран ли трек.
    func isSelected(_ track: LibraryTrack) -> Bool {
        selectedTracksById[track.id] != nil
    }

    /// Переключает выбор одного трека.
    func toggle(_ track: LibraryTrack) {
        if isSelected(track) {
            selectedTracksById.removeValue(forKey: track.id)
        } else {
            selectedTracksById[track.id] = track
        }
    }

    /// Выбирает все переданные треки.
    func selectAll(_ tracks: [LibraryTrack]) {
        for track in tracks {
            selectedTracksById[track.id] = track
        }
    }

    /// Снимает выбор со всех переданных треков.
    func deselectAll(_ tracks: [LibraryTrack]) {
        for track in tracks {
            selectedTracksById.removeValue(forKey: track.id)
        }
    }

    /// Проверяет, выбраны ли все переданные треки.
    func areAllSelected(_ tracks: [LibraryTrack]) -> Bool {
        guard !tracks.isEmpty else { return false }
        return tracks.allSatisfy { selectedTracksById[$0.id] != nil }
    }
}

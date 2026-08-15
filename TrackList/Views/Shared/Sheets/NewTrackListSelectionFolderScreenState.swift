//
//  NewTrackListSelectionFolderScreenState.swift
//  TrackList
//
//  Presentation-состояние папки в flow выбора треков.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Передаёт View готовые selectable-строки и toolbar-состояние выбранной папки.
struct NewTrackListSelectionFolderScreenState {
    /// Готовые секции selectable-строк в отображаемом порядке Library Tracks.
    let sections: [TrackSelectableSectionState]
    /// Треки в порядке отображения для typed Select All и Deselect All действий.
    let visibleTracks: [LibraryTrack]
    /// Показывает initial loading Library Tracks.
    let isLoading: Bool
    /// Указывает, что в текущей папке есть доступные для выбора строки.
    let hasVisibleTracks: Bool
    /// Управляет текстом toolbar-кнопки без query к selection ViewModel.
    let areAllVisibleTracksSelected: Bool
}

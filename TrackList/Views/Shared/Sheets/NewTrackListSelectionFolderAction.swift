//
//  NewTrackListSelectionFolderAction.swift
//  TrackList
//
//  Typed действия экрана папки в flow выбора треков.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Описывает lifecycle и runtime-намерения folder destination без доступа View к Library Tracks ViewModel.
enum NewTrackListSelectionFolderAction {
    /// Folder destination стал видимым и должен выполнить каноничную initial load семантику Library Tracks.
    case screenAppeared
    /// Видимая строка запросила runtime snapshot для своего трека.
    case snapshotRequested(UUID)
}

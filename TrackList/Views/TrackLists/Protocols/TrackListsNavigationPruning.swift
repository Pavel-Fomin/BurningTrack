//
//  TrackListsNavigationPruning.swift
//  TrackList
//
//  Контракт очистки root-detail выбора после изменения master-списка.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Синхронизирует iPad sidebar с уже опубликованным допустимым набором master-идентификаторов.
@MainActor
protocol TrackListsNavigationPruning {

    /// Убирает detail-выбор треклиста, которого больше нет в master-снимке.
    func pruneTrackListSelection(validTrackListIDs: Set<UUID>)
}

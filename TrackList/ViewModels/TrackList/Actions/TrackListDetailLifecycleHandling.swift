//
//  TrackListDetailLifecycleHandling.swift
//  TrackList
//
//  Объявляет lifecycle-границу detail-загрузки одного треклиста.
//
//  Created by Pavel Fomin on 15.08.2026.
//

import Foundation

/// Даёт ActionHandler узкий доступ к lifecycle detail без расширения read-only TrackListReading.
@MainActor
protocol TrackListDetailLifecycleHandling: AnyObject {
    /// Выполняет initial read только при отсутствии согласованного detail snapshot.
    func loadIfNeeded()

    /// Повторяет initial read после initial failure, сохраняя ownership состояния в ViewModel.
    func retryInitialLoad()
}

/// ViewModel остаётся единственным владельцем load-once и retry-семантики detail destination.
extension TrackListViewModel: TrackListDetailLifecycleHandling {}

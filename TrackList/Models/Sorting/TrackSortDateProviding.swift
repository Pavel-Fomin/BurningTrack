//
//  TrackSortDateProviding.swift
//  TrackList
//
//  Общий контракт даты для сортировки треков.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

/// Даёт сортировщику дату только тем моделям, у которых дата имеет явно выбранную семантику.
protocol TrackSortDateProviding {
    /// Дата, которую конкретный источник считает корректной для сортировки трека.
    var trackSortDate: Date? { get }
}

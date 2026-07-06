//
//  LibraryTrack+TrackSortDateProviding.swift
//  TrackList
//
//  Дата сортировки трека фонотеки.
//
//  Created by Pavel Fomin on 04.07.2026.
//

import Foundation

extension LibraryTrack: TrackSortDateProviding {
    /// Для фонотеки addedDate соответствует сохранённой дате файла или индексации.
    var trackSortDate: Date? {
        addedDate
    }
}

//
//  TrackListsLoading.swift
//  TrackList
//
//  Контракт загрузки полного master-снимка треклистов.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Подготавливает полный снимок треклистов для master-flow, пока detail получает TrackList с содержимым.
@MainActor
protocol TrackListsLoading {

    /// Гарантирует системный треклист и возвращает полный снимок master-списка.
    func loadTrackLists() throws -> [TrackList]
}

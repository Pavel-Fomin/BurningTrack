//
//  PurchasedITunesTrackSortMode.swift
//  TrackList
//
//  Режим сортировки треков из системной медиатеки iOS.
//
//  Created by Pavel Fomin on 23.07.2026.
//

import Foundation

/// Описывает только те режимы сортировки, для которых MPMediaItem предоставляет надёжные данные.
enum PurchasedITunesTrackSortMode: String, CaseIterable, Hashable {
    case artistAsc
    case artistDesc
    case titleAsc
    case titleDesc
    case albumAsc
    case albumDesc
    case yearDesc
    case yearAsc
    case genreAsc
    case genreDesc
    case dateAddedDesc
    case dateAddedAsc
}

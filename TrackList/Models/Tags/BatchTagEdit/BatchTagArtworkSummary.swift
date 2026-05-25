//
//  BatchTagArtworkSummary.swift
//  TrackList
//
//  Сводное состояние обложек среди выбранных треков.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

enum BatchTagArtworkSummary: Equatable {
    case none   /// У выбранных треков нет обложек.
    case same   /// У выбранных треков есть одинаковая обложка.
    case mixed  /// У выбранных треков разные состояния или разные обложки.
}

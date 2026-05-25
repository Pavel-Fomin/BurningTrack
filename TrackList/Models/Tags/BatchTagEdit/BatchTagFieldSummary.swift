//
//  BatchTagFieldSummary.swift
//  TrackList
//
//  Сводное состояние значения поля среди выбранных треков.
//
//  Created by Pavel Fomin on 25.05.2026.
//

import Foundation

enum BatchTagFieldSummary: Equatable {
    case empty         /// У всех выбранных треков поле пустое.
    case same(String)  /// У всех выбранных треков одинаковое значение.
    case mixed         /// У выбранных треков разные значения.
}

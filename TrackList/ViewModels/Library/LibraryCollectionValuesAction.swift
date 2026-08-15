//
//  LibraryCollectionValuesAction.swift
//  TrackList
//
//  Typed действия экрана значений музыкальной коллекции.
//
//  Created by Pavel Fomin on 14.08.2026.
//

import Foundation

/// Описывает пользовательские и lifecycle-намерения экрана значений коллекции.
enum LibraryCollectionValuesAction {
    /// Экран стал видимым и может один раз запросить значения.
    case screenAppeared
    /// Пользователь выбрал допустимый режим сортировки значений.
    case sortModeSelected(LibraryCollectionValueSortMode)
}

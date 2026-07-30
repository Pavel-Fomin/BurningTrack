//
//  FavoritesMutationResult.swift
//  TrackList
//
//  Результат изменения системного треклиста «Избранное».
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Описывает итог изменения избранного без UI-текста и без необходимости повторно читать хранилище.
enum FavoritesMutationResult: Equatable {
    /// Трек был добавлен в «Избранное».
    case added
    /// Все вхождения трека были удалены из «Избранного».
    case removed
    /// Операция не изменила данные; параметр содержит итоговое булево состояние.
    case unchanged(isFavorite: Bool)

    /// Итоговое наличие трека в «Избранном» после операции.
    var isFavorite: Bool {
        switch self {
        case .added:
            true
        case .removed:
            false
        case let .unchanged(isFavorite):
            isFavorite
        }
    }

    /// Признак фактического изменения содержимого системного треклиста.
    var didChange: Bool {
        switch self {
        case .added, .removed:
            true
        case .unchanged:
            false
        }
    }
}

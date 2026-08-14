//
//  RenameTrackListFlowProtocols.swift
//  TrackList
//
//  Контракты маршрутизации feature-flow переименования треклиста.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Маршрутизирует завершение sheet переименования треклиста.
@MainActor
protocol RenameTrackListRouting {
    /// Закрывает только route переименования с переданной идентичностью.
    func dismissRenameTrackList(_ routeID: UUID)
}

// MARK: - Адаптер production-слоя

extension SheetManager: RenameTrackListRouting {}

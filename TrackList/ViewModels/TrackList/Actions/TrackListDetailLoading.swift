//
//  TrackListDetailLoading.swift
//  TrackList
//
//  Узкое чтение полного снимка одного треклиста для detail-flow.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Загружает согласованный снимок одного треклиста по неизменяемому маршруту detail-экрана.
@MainActor
protocol TrackListDetailLoading {
    /// Возвращает метаданные и строки запрошенного треклиста либо семантическую ошибку чтения.
    func loadTrackList(id: UUID) throws -> TrackList
}

extension TrackListManager: TrackListDetailLoading {
    /// Адаптирует существующее чтение SQLite-модели к узкому контракту detail-flow.
    func loadTrackList(id: UUID) throws -> TrackList {
        try getTrackListById(id)
    }
}

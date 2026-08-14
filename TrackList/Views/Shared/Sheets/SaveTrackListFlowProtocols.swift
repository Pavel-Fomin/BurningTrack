//
//  SaveTrackListFlowProtocols.swift
//  TrackList
//
//  Явные зависимости sheet-flow сохранения очереди плеера в треклист.
//
//  Created by Pavel Fomin on 04.08.2026.
//

import Foundation

/// Возвращает актуальный снимок очереди плеера только в момент сохранения.
@MainActor
protocol SaveTrackListQueueProviding {
    /// Преобразует текущую очередь в доменные треки, сохраняя порядок элементов.
    func currentQueueTracks() -> [Track]
}

/// Создаёт новый треклист из переданных доменных треков.
@MainActor
protocol SaveTrackListCreating {
    /// Сохраняет новый обычный треклист с указанным именем и порядком треков.
    func createTrackList(
        from tracks: [Track],
        withName name: String
    ) throws -> TrackList
}

/// Маршрутизирует завершение sheet сохранения очереди.
@MainActor
protocol SaveTrackListRouting {
    /// Закрывает только route сохранения с переданной идентичностью.
    func dismissSaveTrackList(_ routeID: UUID)
}

// MARK: - Адаптеры production-слоя

extension PlaylistManager: SaveTrackListQueueProviding {
    /// Возвращает актуальную очередь на момент подтверждения без изменения её порядка.
    func currentQueueTracks() -> [Track] {
        tracks.map { $0.asTrack() }
    }
}

extension TrackListsManager: SaveTrackListCreating {}

extension SheetManager: SaveTrackListRouting {}

//
//  TrackListsLoader.swift
//  TrackList
//
//  Загрузка полного master-снимка треклистов.
//
//  Created by Pavel Fomin on 13.08.2026.
//

import Foundation

/// Загружает только согласованный полный снимок, потому что текущий detail ещё получает TrackList с Track[].
@MainActor
final class TrackListsLoader: TrackListsLoading {

    /// Управляет метаданными master-списка и существованием системного треклиста.
    private let trackListsManager: any TrackListsManaging
    /// Загружает содержимое каждого треклиста для существующего initial contract detail-flow.
    private let trackListManager: any TrackListManaging

    init(
        trackListsManager: any TrackListsManaging,
        trackListManager: any TrackListManaging
    ) {
        self.trackListsManager = trackListsManager
        self.trackListManager = trackListManager
    }

    /// Возвращает новый снимок только после успешной загрузки каждого треклиста.
    func loadTrackLists() throws -> [TrackList] {
        do {
            // Системный треклист должен существовать до публикации итогового списка в интерфейс.
            _ = try trackListsManager.ensureFavoritesTrackList()
            let metas = try trackListsManager.loadTrackListMetas()

            return try metas.map { meta in
                TrackList(
                    id: meta.id,
                    name: meta.name,
                    createdAt: meta.createdAt,
                    kind: meta.kind,
                    tracks: try trackListManager.loadTracks(for: meta.id)
                )
            }
        } catch let appError as AppError {
            throw appError
        } catch {
            throw AppError.trackListLoadFailed
        }
    }
}

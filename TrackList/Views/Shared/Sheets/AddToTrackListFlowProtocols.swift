//
//  AddToTrackListFlowProtocols.swift
//  TrackList
//
//  Контракты зависимостей feature-flow добавления треков в треклист.
//
//  Created by Pavel Fomin on 03.08.2026.
//

import Foundation

/// Загружает destination-треклисты и выполняет Library batch-операцию feature-flow.
@MainActor
protocol AddToTrackListTrackListsManaging {
    /// Возвращает метаданные доступных destination-треклистов.
    func loadTrackListMetas() throws -> [TrackListMeta]

    /// Добавляет выбранные треки фонотеки в destination-треклист.
    @discardableResult
    func addTracks(_ libraryTracks: [LibraryTrack], to trackListId: UUID) throws -> TrackList
}

/// Выполняет ID-based и Purchased iTunes-команды добавления треков в треклист.
/// Команды начинаются в общем MainActor-bound application flow, а файловая работа остаётся у actor-owner-ов.
@MainActor
protocol AddToTrackListExecuting {
    /// Добавляет один файловый трек в destination-треклист.
    func addTrackToTrackList(
        trackId: UUID,
        trackListId: UUID
    ) async throws -> TrackAddedToTrackListSuccess

    /// Добавляет несколько файловых треков в destination-треклист.
    func addTracksToTrackList(
        trackIds: [UUID],
        trackListId: UUID
    ) async throws -> TracksAddedToTrackListSuccess

    /// Добавляет купленные iTunes-треки в destination-треклист.
    func addPurchasedITunesTracksToTrackList(
        _ tracks: [PurchasedITunesPlayableTrack],
        trackListId: UUID
    ) async throws -> PurchasedITunesTracksAddedToTrackListSuccess
}

/// Маршрутизирует завершение sheet Add To TrackList.
@MainActor
protocol AddToTrackListRouting {
    /// Закрывает только route добавления с переданной идентичностью.
    func dismissAddToTrackList(_ routeID: UUID)
}

// MARK: - Адаптеры production-слоя

extension TrackListsManager: AddToTrackListTrackListsManaging {}

extension AppCommandExecutor: AddToTrackListExecuting {}

extension SheetManager: AddToTrackListRouting {}

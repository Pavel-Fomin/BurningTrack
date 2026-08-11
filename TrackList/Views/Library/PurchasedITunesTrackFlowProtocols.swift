//
//  PurchasedITunesTrackFlowProtocols.swift
//  TrackList
//
//  Узкие capability-контракты строкового flow «Куплено в iTunes».
//
//  Created by Pavel Fomin on 11.08.2026.
//

import Foundation

/// Выполняет sheet-маршруты строки без раскрытия ActionHandler-у глобального SheetManager.
@MainActor
protocol PurchasedITunesTrackRouting: AnyObject {
    func presentCopyPurchasedITunesToFolder(for track: PurchasedITunesPlayableTrack)
    func presentTrackDetail(_ track: any TrackDisplayable)
    func presentAddToTrackList(for track: any TrackDisplayable, sourceTrackListId: UUID?)
}

/// Выполняет единственную команду добавления iTunes-трека в плеер.
protocol PurchasedITunesTrackPlayerAdding: AnyObject {
    func addPurchasedITunesTrackToPlayer(
        _ track: PurchasedITunesPlayableTrack
    ) async throws -> PurchasedITunesTrackAddedToPlayerSuccess
}

/// Отправляет runtime iTunes-ассет в существующий единый share-flow.
@MainActor
protocol PurchasedITunesTrackSharing: AnyObject {
    func sharePurchasedITunesTrack(_ track: PurchasedITunesPlayableTrack)
}

// MARK: - Production adapters

extension SheetManager: PurchasedITunesTrackRouting {}
extension AppCommandExecutor: PurchasedITunesTrackPlayerAdding {}
extension TrackShareActionHandler: PurchasedITunesTrackSharing {}

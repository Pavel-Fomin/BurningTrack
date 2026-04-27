//
//  TrackMetadataProviding.swift
//  TrackList
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation


@MainActor
protocol TrackMetadataProviding: AnyObject {

    /// Возвращает runtime snapshot трека (если уже есть)
    func snapshot(for trackId: UUID) -> TrackRuntimeSnapshot?

    /// Запрашивает загрузку snapshot, если он ещё не получен
    func requestSnapshotIfNeeded(for trackId: UUID)
}

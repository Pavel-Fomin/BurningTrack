//
//  TrackMetadataProviding.swift
//  TrackList
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation


@MainActor
protocol TrackMetadataProviding: AnyObject {

    /// Возвращает загруженные metadata для трека (если есть)
    func metadata(for trackId: UUID)
        -> TrackMetadataCacheManager.CachedMetadata?

    /// Запрашивает загрузку metadata, если она ещё не выполнена
    func requestMetadataIfNeeded(for trackId: UUID)
}

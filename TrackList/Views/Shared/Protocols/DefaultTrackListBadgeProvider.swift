//
//  DefaultTrackListBadgeProvider.swift
//  TrackList
//
//  Провайдер бейджей треклистов.
//
//  Роль:
//  - предоставляет названия треклистов по trackId;
//  - использует централизованный индекс TrackListBadgeIndex;
//  - не читает JSON напрямую.
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation

final class DefaultTrackListBadgeProvider: TrackListBadgeProvider {

    // MARK: - Public

    func badges(for trackIds: [UUID]) -> [UUID: [String]] {
        TrackListBadgeIndex.shared.badges(for: trackIds)
    }
}

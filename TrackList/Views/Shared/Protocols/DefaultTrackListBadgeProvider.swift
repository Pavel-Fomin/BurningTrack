//
//  DefaultTrackListBadgeProvider.swift
//  TrackList
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation


final class DefaultTrackListBadgeProvider: TrackListBadgeProvider {

    func badges(for trackIds: [UUID]) -> [UUID: [String]] {

        var namesById: [UUID: Set<String>] = [:]

        let metas = (try? TrackListsManager.shared.loadTrackListMetas()) ?? []

        for meta in metas {
            guard let list = try? TrackListManager.shared.getTrackListById(meta.id) else {
                continue
            }
            for track in list.tracks {
                if trackIds.contains(track.id) {
                    namesById[track.id, default: []].insert(meta.name)
                }
            }
        }

        var result: [UUID: [String]] = [:]
        for id in trackIds {
            result[id] = Array(namesById[id] ?? []).sorted()
        }

        return result
    }
}

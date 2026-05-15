//
//  TrackListBadgeIndex.swift
//  TrackList
//
//  Индекс бейджей треклистов.
//
//  Роль:
//  - хранит быстрый доступ к названиям треклистов по trackId;
//  - централизует расчёт membership-бейджей;
//  - убирает повторное чтение JSON из provider;
//  - перестраивается при изменении списка треклистов или состава треков.
//
//  Created by Pavel Fomin on 15.05.2026.
//

import Foundation

final class TrackListBadgeIndex {

    static let shared = TrackListBadgeIndex()

    // MARK: - State

    private var badgesByTrackId: [UUID: [String]] = [:]
    private var observers: [NSObjectProtocol] = []

    // MARK: - Init

    private init() {
        rebuild()
        observeTrackListChanges()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public

    func badges(for trackIds: [UUID]) -> [UUID: [String]] {
        var result: [UUID: [String]] = [:]

        for trackId in trackIds {
            result[trackId] = badgesByTrackId[trackId] ?? []
        }

        return result
    }

    func rebuild() {
        var nextIndex: [UUID: Set<String>] = [:]

        let metas = (try? TrackListsManager.shared.loadTrackListMetas()) ?? []

        for meta in metas {
            let tracks = (try? TrackListManager.shared.loadTracks(for: meta.id)) ?? []

            for track in tracks {
                nextIndex[track.trackId, default: []].insert(meta.name)
            }
        }

        badgesByTrackId = nextIndex.reduce(into: [:]) { result, item in
            result[item.key] = Array(item.value).sorted()
        }
    }

    // MARK: - Observing

    private func observeTrackListChanges() {
        let trackListsObserver = NotificationCenter.default.addObserver(
            forName: .trackListsDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuild()
        }

        let trackListTracksObserver = NotificationCenter.default.addObserver(
            forName: .trackListTracksDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rebuild()
        }

        observers.append(trackListsObserver)
        observers.append(trackListTracksObserver)
    }
}

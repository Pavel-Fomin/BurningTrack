//
//  TrackListBadgeIndex.swift
//  TrackList
//
//  Индекс бейджей треклистов.
//
//  Роль:
//  - хранит быстрый доступ к семантическим принадлежностям треклистов по trackId;
//  - централизует расчёт membership-бейджей;
//  - убирает повторный обход треклистов из provider;
//  - перестраивается при изменении списка треклистов или состава треков.
//
//  Created by Pavel Fomin on 15.05.2026.
//

import Foundation

final class TrackListBadgeIndex {

    static let shared = TrackListBadgeIndex()

    // MARK: - State

    private var badgesByTrackId: [UUID: [TrackListMembership]] = [:]
    private var observers: [NSObjectProtocol] = []
    private let trackListsManager: TrackListsManager
    private let trackListManager: TrackListManager

    // MARK: - Init

    /// Создаёт индекс с явными зависимостями, чтобы поиск использовал тот же источник треклистов, что и фонотека.
    init(
        trackListsManager: TrackListsManager = .shared,
        trackListManager: TrackListManager = .shared,
        observesTrackListChanges: Bool = true
    ) {
        self.trackListsManager = trackListsManager
        self.trackListManager = trackListManager
        rebuild()
        if observesTrackListChanges {
            observeTrackListChanges()
        }
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Public

    func badges(for trackIds: [UUID]) -> [UUID: [TrackListMembership]] {
        var result: [UUID: [TrackListMembership]] = [:]

        for trackId in trackIds {
            result[trackId] = badgesByTrackId[trackId] ?? []
        }

        return result
    }

    func rebuild() {
        var nextIndex: [UUID: Set<TrackListMembership>] = [:]

        let metas = (try? trackListsManager.loadTrackListMetas()) ?? []

        for meta in metas {
            let tracks = (try? trackListManager.loadTracks(for: meta.id)) ?? []

            for track in tracks {
                nextIndex[track.trackId, default: []].insert(
                    TrackListMembership(
                        storedName: meta.name,
                        kind: meta.kind
                    )
                )
            }
        }

        badgesByTrackId = nextIndex.reduce(into: [:]) { result, item in
            result[item.key] = item.value.sorted {
                $0.storedName.localizedCaseInsensitiveCompare($1.storedName) == .orderedAscending
            }
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

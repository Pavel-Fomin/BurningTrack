//
//  TrackList.swift
//  TrackList
//
//  Полная модель одного треклиста:
//  - идентификатор;
//  - название;
//  - дата создания;
//  - назначение;
//  - треки.
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation

struct TrackList: Identifiable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    /// Назначение треклиста.
    let kind: TrackListKind
    var tracks: [Track]
}

enum TrackListsSortMode: String, CaseIterable {
    case createdAt
    case name

    /// Возвращает отображаемый порядок с закреплённым системным треклистом перед пользовательскими.
    func applying(to trackLists: [TrackList]) -> [TrackList] {
        let favorites = trackLists.filter { $0.kind == .favorites }
        var regularTrackLists = trackLists.filter { $0.kind == .regular }

        switch self {
        case .createdAt:
            regularTrackLists.sort { $0.createdAt > $1.createdAt }
        case .name:
            regularTrackLists.sort {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        }

        return favorites + regularTrackLists
    }

    /// Возвращает сохранённый ручной порядок с закреплённым системным треклистом.
    static func manualOrder(from trackLists: [TrackList]) -> [TrackList] {
        trackLists.filter { $0.kind == .favorites } +
        trackLists.filter { $0.kind == .regular }
    }
}

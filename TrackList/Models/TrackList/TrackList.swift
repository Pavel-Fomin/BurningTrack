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
}

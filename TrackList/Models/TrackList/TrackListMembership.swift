//
//  TrackListMembership.swift
//  TrackList
//
//  Семантическая принадлежность трека к треклисту.
//
//  Created by Pavel Fomin on 30.07.2026.
//

import Foundation

/// Передаёт сохранённое имя и назначение треклиста в presentation-слой без локализации в manager-слое.
struct TrackListMembership: Hashable {
    let storedName: String
    let kind: TrackListKind
}

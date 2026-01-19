//
//  TrackSection.swift
//  TrackList
//
//  Модель секции по дате
//
//  Created by Pavel Fomin on 09.08.2025.
//

import Foundation

struct TrackSection: Identifiable, Equatable {
    let id: String
    let title: String
    let tracks: [LibraryTrack]

    // Достаточно поверхностного сравнения для SwiftUI:
    static func == (lhs: TrackSection, rhs: TrackSection) -> Bool {
        lhs.id == rhs.id && lhs.tracks.count == rhs.tracks.count
    }
}

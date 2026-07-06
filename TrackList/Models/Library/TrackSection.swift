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
    let showsHeader: Bool

    init(
        id: String,
        title: String,
        tracks: [LibraryTrack],
        showsHeader: Bool = true
    ) {
        self.id = id
        self.title = title
        self.tracks = tracks
        self.showsHeader = showsHeader
    }

    // SwiftUI должен видеть изменение порядка строк даже при прежнем количестве треков.
    static func == (lhs: TrackSection, rhs: TrackSection) -> Bool {
        lhs.id == rhs.id
            && lhs.title == rhs.title
            && lhs.showsHeader == rhs.showsHeader
            && lhs.tracks.map(\.id) == rhs.tracks.map(\.id)
    }
}

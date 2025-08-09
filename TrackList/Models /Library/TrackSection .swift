//
//  TrackSection .swift
//  TrackList
//
//  Модель секции по дате
//
//  Created by Pavel Fomin on 09.08.2025.
//

import Foundation

struct TrackSection: Identifiable {
    let id: String
    let title: String
    let tracks: [LibraryTrack]
}

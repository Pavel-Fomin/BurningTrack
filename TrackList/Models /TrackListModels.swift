//
//  TrackListModels.swift
//  TrackList
//
//  Модель треклиста, включающая список ImportedTrack
//
//  Created by Pavel Fomin on 27.04.2025.
//

import Foundation

struct TrackList: Codable, Identifiable {
    let id: UUID
    var name: String
    let createdAt: Date
    var tracks: [ImportedTrack]
}

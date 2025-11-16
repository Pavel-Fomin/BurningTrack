//
//  TrackList.swift
//  TrackList
//
//  Полная модель одного треклиста:
//  - id
//  - name
//  - createdAt
//  - tracks: [Track]
//
//  Created by Pavel Fomin on 01.05.2025.
//

import Foundation

struct TrackList: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var tracks: [Track]
}

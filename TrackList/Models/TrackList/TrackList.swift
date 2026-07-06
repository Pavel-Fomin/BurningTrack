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

struct TrackList: Identifiable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var tracks: [Track]
}

enum TrackListsSortMode: String, CaseIterable {
    case createdAt
    case name

    /// Название пункта сортировки в меню.
    var title: String {
        switch self {
        case .createdAt:
            return "По дате"
        case .name:
            return "По названию"
        }
    }

    /// Подпись текущей сортировки под пунктом меню.
    var caption: String {
        switch self {
        case .createdAt:
            return "по дате"
        case .name:
            return "по названию"
        }
    }
}

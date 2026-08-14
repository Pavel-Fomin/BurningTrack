//
//  TrackListBadgeProvider.swift
//  TrackList
//
//  Объявляет read-only источник принадлежности треков пользовательским треклистам.
//
//  Created by Pavel Fomin on 13.12.2025.
//

import Foundation


protocol TrackListBadgeProvider {
    func badges(for trackIds: [UUID]) -> [UUID: [TrackListMembership]]
}
